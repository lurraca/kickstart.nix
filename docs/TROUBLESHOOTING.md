# Troubleshooting Guide

This guide covers common issues and their solutions when working with this nix-darwin configuration.

## Common Issues

### 1. "Experimental features" error

**Error message:**
```
error: experimental Nix feature 'nix-command' is disabled
error: experimental Nix feature 'flakes' is disabled
```

**Solution:**
Add the following to `/etc/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

Then restart your terminal or run:
```bash
source /etc/static/bashrc
```

### 2. "darwin-rebuild: command not found"

**Solution:**
Add nix-darwin to your PATH:
```bash
export PATH=/run/current-system/sw/bin:$PATH
```

Or add to your `.zshrc`:
```bash
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
```

### 3. Homebrew packages not installing

**Error message:**
```
Error: homebrew-core is a shallow clone
```

**Solution:**
```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Fix shallow clone issue
git -C "$(brew --repo homebrew/core)" fetch --unshallow
```

### 4. Permission denied errors

**Error message:**
```
error: opening lock file '/nix/var/nix/profiles/per-user/root/profile.lock': Permission denied
```

**Solution:**
Use sudo for system-level changes:
```bash
sudo darwin-rebuild switch --flake .#X7X56XWY9W
```

### 5. Flake registry issues

**Error message:**
```
error: unable to download 'https://api.github.com/repos/NixOS/nixpkgs/tarball/nixpkgs-unstable': HTTP error 403
```

**Solution:**
This is often a rate limiting issue. Try:
```bash
# Use a specific nixpkgs commit
nix flake update --override-input nixpkgs github:NixOS/nixpkgs/<commit-hash>

# Or wait and try again later
```

### 6. Home-manager conflicts

**Error message:**
```
error: The option `home-manager.users.username.home.file."xxx"' has conflicting definitions
```

**Solution:**
Check for duplicate definitions in your configuration files. Common causes:
- Same file defined in multiple places
- Conflicting program configurations

### 7. macOS-specific issues

#### 7a. Spotlight indexing /nix/store

**Solution:**
Exclude /nix from Spotlight:
```bash
sudo mdutil -i off /nix
```

#### 7b. Time Machine backing up /nix/store

**Solution:**
Exclude /nix from Time Machine:
```bash
sudo tmutil addexclusion -p /nix
```

### 8. Build failures

#### 8a. Out of disk space

**Error message:**
```
error: writing to file: No space left on device
```

**Solution:**
Clean up old generations:
```bash
# Remove all old generations
sudo nix-collect-garbage -d

# Remove generations older than 7 days
sudo nix-collect-garbage --delete-older-than 7d

# Check disk usage
df -h /nix/store
du -sh /nix/store
```

#### 8b. Hash mismatch

**Error message:**
```
error: hash mismatch in fixed-output derivation
```

**Solution:**
Clear the cache and retry:
```bash
nix-store --verify --check-contents
nix-store --gc
```

### 9. Shell configuration not loading

**Symptoms:**
- Aliases not working
- Programs not in PATH
- Prompt not displaying correctly

**Solution:**
1. Ensure home-manager activation worked:
```bash
home-manager switch
```

2. Check if shell is managed by nix:
```bash
echo $SHELL
which zsh
```

3. Manually source configuration:
```bash
source ~/.zshrc
```

### 10. Git configuration conflicts

**Error message:**
```
error: could not lock config file .git/config: File exists
```

**Solution:**
Home-manager manages git config. Remove manual git config:
```bash
rm ~/.gitconfig
darwin-rebuild switch --flake .#X7X56XWY9W
```

## Debugging Commands

### Check system status
```bash
# View current system generation
darwin-rebuild --list-generations

# Check nix store integrity
nix-store --verify --check-contents

# View current PATH
echo $PATH | tr ':' '\n'

# Check which packages are installed
nix-env -q
```

### Rollback changes
```bash
# List generations
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild --rollback

# Switch to specific generation
darwin-rebuild switch --switch-generation <number>
```

### Verbose output
```bash
# Build with verbose output
darwin-rebuild switch --flake .#X7X56XWY9W --show-trace -v

# Debug flake evaluation
nix flake show
nix flake check
```

## Getting Help

### Resources
- [Nix-darwin issues](https://github.com/LnL7/nix-darwin/issues)
- [Home-manager issues](https://github.com/nix-community/home-manager/issues)
- [NixOS Discourse](https://discourse.nixos.org/)
- [Nix-darwin Matrix channel](https://matrix.to/#/#nix-darwin:matrix.org)

### Useful commands for debugging
```bash
# Show what would be built
nix build .#darwinConfigurations.X7X56XWY9W.system --dry-run

# Show derivation details
nix show-derivation .#darwinConfigurations.X7X56XWY9W.system

# Interactive Nix REPL
nix repl
> :lf .
> darwinConfigurations.X7X56XWY9W.config
```

## Prevention Tips

1. **Always check before switching**
   ```bash
   darwin-rebuild check --flake .#X7X56XWY9W
   ```

2. **Keep backups**
   - Use git for your configuration
   - Tag working configurations
   - Document changes

3. **Test changes incrementally**
   - Make small changes
   - Test each change before making more
   - Use `darwin-rebuild build` before `switch`

4. **Monitor disk usage**
   ```bash
   # Add to your shell config
   alias nix-usage='du -sh /nix/store'
   ```