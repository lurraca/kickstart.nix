# Luis's Nix-Darwin Configuration

A declarative system configuration for macOS using [nix-darwin](https://github.com/LnL7/nix-darwin), [home-manager](https://github.com/nix-community/home-manager), and [Nix flakes](https://nixos.wiki/wiki/Flakes).

## Overview

This repository contains my personal macOS system configuration, managing:
- System packages and applications
- Development environment (Node.js, Rust, Ruby, etc.)
- Shell configuration (Zsh with Oh My Zsh)
- Terminal applications (Alacritty, tmux, Neovim)
- Git configuration
- Homebrew packages and casks
- Font management

## Structure

```
.
├── flake.nix                 # Flake configuration entry point
├── flake.lock               # Locked dependencies
├── darwin.nix               # Legacy darwin entry (for compatibility)
├── lib/
│   └── homebrew.nix         # Homebrew packages and casks
└── module/
    ├── configuration.nix    # System-level configuration
    └── home-manager.nix     # User-level configuration
```

## Prerequisites

- macOS (tested on Apple Silicon)
- Xcode Command Line Tools: `xcode-select --install`
- [Nix package manager](https://nixos.org/download.html) with flakes enabled

## Installation

### 1. Install Nix

```bash
# Install Nix (if not already installed)
curl -L https://nixos.org/nix/install | sh

# Enable flakes (add to ~/.config/nix/nix.conf or /etc/nix/nix.conf)
experimental-features = nix-command flakes
```

### 2. Clone this repository

```bash
# Clone to the expected location
sudo git clone https://github.com/yourusername/nix-darwin-config /etc/nix-darwin

# Or symlink from another location
git clone https://github.com/yourusername/nix-darwin-config ~/nix-darwin-config
sudo ln -s ~/nix-darwin-config /etc/nix-darwin
```

### 3. Update configuration

Edit the configuration files to match your setup:

- Update username in `flake.nix` (line 14)
- Update home directory in `module/configuration.nix` (line 34)
- Update git email in `module/home-manager.nix` (line 101)

### 4. Build and apply

```bash
cd /etc/nix-darwin

# First time setup
nix build .#darwinConfigurations.X7X56XWY9W.system
./result/sw/bin/darwin-rebuild switch --flake .#X7X56XWY9W

# Subsequent updates
darwin-rebuild switch --flake .#X7X56XWY9W
```

## Usage

### Daily Commands

```bash
# Apply configuration changes
darwin-rebuild switch --flake /etc/nix-darwin#X7X56XWY9W

# Check configuration without applying
darwin-rebuild check --flake /etc/nix-darwin#X7X56XWY9W

# Update flake inputs (packages)
cd /etc/nix-darwin && nix flake update

# Garbage collection
nix-collect-garbage -d

# Search for packages
nix search nixpkgs <package-name>
```

## Cheatsheet

### Running Alacritty

**From WSL Terminal (Current Method):**
```bash
~/.local/bin/alacritty-wrapped &
```

**From Windows (VBScript - No CMD window):**
1. Double-click: `%USERPROFILE%\alacritty.vbs`
2. Or Win+R: `wscript %USERPROFILE%\alacritty.vbs`

**From Windows (Batch - With CMD window):**
```
Win+R -> %USERPROFILE%\alacritty.bat
```

**Create Start Menu Shortcut:**
1. Right-click Desktop → New → Shortcut
2. Location: `wscript %USERPROFILE%\alacritty.vbs`
3. Name: "Alacritty"
4. Move to: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\`

### Shell Aliases

The configuration includes many useful aliases:

| Alias | Command | Description |
|-------|---------|-------------|
| `drs` | `darwin-rebuild switch --flake ".#x86_64"` | Rebuild and switch configuration |
| `drc` | `darwin-rebuild check --flake ".#x86_64"` | Check configuration |
| `ll` | `ls -lah` | List files with details |
| `gst` | `git status` | Git status |
| `gco` | `git checkout` | Git checkout |
| `k` | `kubectl` | Kubernetes CLI |
| `v` | `nvim` | Neovim editor |

See `module/home-manager.nix` for the complete list.

## Installed Software

### Development Tools
- **Languages**: Node.js 24, Ruby, Rust (via rustup), Lua
- **Editors**: Neovim, JetBrains GoLand, IntelliJ IDEA Ultimate
- **Version Control**: Git with delta diff tool, GitHub CLI, tig
- **Cloud Tools**: AWS CLI, ECR credential helper, SAML2AWS, SSM Session Manager

### Terminal Environment
- **Shell**: Zsh with Oh My Zsh
- **Terminal**: Alacritty
- **Multiplexer**: tmux
- **Prompt**: Starship
- **Utilities**: eza (ls replacement), bat (cat replacement), ripgrep, fzf, bottom (system monitor)

### Applications
- Discord
- Slack
- Zoom
- Raycast
- 1Password
- Arc Browser
- Notion
- GitHub Desktop

### Fonts
- Fira Code Nerd Font
- Fira Mono Nerd Font
- Hack Nerd Font
- JetBrains Mono Nerd Font

## Customization

### Adding Packages

1. **Nix packages**: Edit `module/home-manager.nix`, add to `home.packages`
2. **Homebrew formulas**: Edit `lib/homebrew.nix`, add to `homebrew.brews`
3. **Homebrew casks**: Edit `lib/homebrew.nix`, add to `homebrew.casks`

### Modifying Shell Configuration

Edit `module/home-manager.nix`:
- Shell aliases: `programs.zsh.shellAliases`
- Zsh plugins: `programs.zsh.oh-my-zsh.plugins`
- Environment variables: `home.sessionVariables`

### Changing System Settings

Edit `module/configuration.nix`:
- Nix settings: `nix.settings`
- System packages: `environment.systemPackages`
- Fonts: `fonts.packages`

## Troubleshooting

### "Experimental features" error

Add to `/etc/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

### "darwin-rebuild: command not found"

Add to your shell profile:
```bash
export PATH=/run/current-system/sw/bin:$PATH
```

### Homebrew packages not installing

Ensure Homebrew is installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Permission issues

Some operations require sudo:
```bash
sudo darwin-rebuild switch --flake .#X7X56XWY9W
```

## Maintenance

### Regular Updates

```bash
# Update all flake inputs
cd /etc/nix-darwin
nix flake update
darwin-rebuild switch --flake .#X7X56XWY9W

# Update specific input
nix flake lock --update-input nixpkgs
```

### Cleaning Up

```bash
# Remove old generations
sudo nix-collect-garbage -d

# Remove old generations older than 7 days
sudo nix-collect-garbage --delete-older-than 7d

# Check store size
du -sh /nix/store
```

## Resources

- [Nix-darwin Manual](https://daiderd.com/nix-darwin/manual/index.html)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Package Search](https://search.nixos.org/packages)
- [Nix Flakes Guide](https://nixos.wiki/wiki/Flakes)

## License

This configuration is provided as-is for reference and inspiration. Feel free to use any parts that are useful for your own configuration.