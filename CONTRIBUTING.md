# Contributing Guide

This document provides guidelines for making changes to this nix-darwin configuration.

## Development Workflow

### 1. Before Making Changes

Always ensure you have a working configuration:
```bash
# Check current status
darwin-rebuild check --flake .#X7X56XWY9W

# Create a git branch for your changes
git checkout -b feature/your-change-name
```

### 2. Making Changes

#### Adding Packages

**Nix packages** (from nixpkgs):
```nix
# In module/home-manager.nix
home.packages = with pkgs; [
  # Existing packages...
  your-new-package
];
```

**Homebrew packages**:
```nix
# In lib/homebrew.nix
homebrew.brews = [
  # Existing brews...
  "your-brew-formula"
];

homebrew.casks = [
  # Existing casks...
  "your-cask-app"  
];
```

#### Modifying System Configuration

Edit `module/configuration.nix` for:
- System-wide settings
- Nix daemon configuration
- User account settings
- Font packages

#### Modifying User Configuration

Edit `module/home-manager.nix` for:
- User packages
- Shell configuration
- Program settings
- Environment variables

### 3. Testing Changes

```bash
# Step 1: Check syntax
darwin-rebuild check --flake .#X7X56XWY9W

# Step 2: Build without switching
darwin-rebuild build --flake .#X7X56XWY9W

# Step 3: Review what will change
ls -la ./result

# Step 4: Apply changes
darwin-rebuild switch --flake .#X7X56XWY9W
```

### 4. Committing Changes

```bash
# Add files
git add .

# Commit with descriptive message
git commit -m "type: description

- Detail 1
- Detail 2"
```

Commit message types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `pkg`: Package additions/updates
- `chore`: Maintenance tasks

## Best Practices

### 1. Configuration Structure

**DO:**
- Keep related configuration together
- Use meaningful variable names
- Comment complex configurations
- Follow existing patterns

**DON'T:**
- Mix system and user configuration
- Hardcode sensitive information
- Create circular dependencies
- Ignore error messages

### 2. Package Management

**Before adding a package, consider:**
- Is it available in nixpkgs? (preferred)
- Is it macOS-specific? (use Homebrew)
- Is it a GUI app? (use Homebrew casks)
- Is it development-specific? (use direnv/shell.nix)

**Search for packages:**
```bash
# Search nixpkgs
nix search nixpkgs packagename

# Search homebrew
brew search packagename
```

### 3. Testing

**Always test in this order:**
1. Syntax check (`darwin-rebuild check`)
2. Build test (`darwin-rebuild build`)
3. Apply to system (`darwin-rebuild switch`)
4. Verify functionality
5. Commit changes

### 4. Documentation

Update documentation when you:
- Add new aliases or functions
- Change system behavior
- Add complex configuration
- Discover new troubleshooting steps

Files to update:
- `README.md` - Major changes
- `docs/ALIASES.md` - New aliases/functions
- `docs/TROUBLESHOOTING.md` - New issues/solutions
- `CLAUDE.md` - Structural changes

## Common Tasks

### Update All Packages

```bash
# Update flake inputs
nix flake update

# Apply updates
darwin-rebuild switch --flake .#X7X56XWY9W

# Update homebrew packages
brew update && brew upgrade
```

### Add a New Shell Alias

```nix
# In module/home-manager.nix
programs.zsh.shellAliases = {
  # Existing aliases...
  "newalias" = "command";
};
```

### Configure a New Program

```nix
# In module/home-manager.nix
programs.programname = {
  enable = true;
  # Program-specific settings
  settings = {
    option1 = "value1";
    option2 = true;
  };
};
```

### Add Environment Variable

```nix
# In module/home-manager.nix
home.sessionVariables = {
  # Existing variables...
  NEW_VARIABLE = "value";
};
```

## Code Style

### Nix Formatting

Use `nixpkgs-fmt` for consistent formatting:
```bash
# Install
nix-env -iA nixpkgs.nixpkgs-fmt

# Format files
nixpkgs-fmt module/*.nix lib/*.nix
```

### General Guidelines

1. **Indentation**: 2 spaces
2. **Line length**: Prefer under 80 characters
3. **Lists**: One item per line for long lists
4. **Comments**: Explain why, not what
5. **Imports**: At the top of the file

Example:
```nix
{ config, pkgs, lib, ... }:

{
  # Enable program with custom settings for better productivity
  programs.example = {
    enable = true;
    
    settings = {
      option1 = true;
      option2 = "value";
    };
    
    # Long list - one per line
    plugins = [
      pkgs.plugin1
      pkgs.plugin2
      pkgs.plugin3
    ];
  };
}
```

## Getting Help

### Resources

- [Nix Pills](https://nixos.org/guides/nix-pills/) - Learn Nix concepts
- [Home Manager Options](https://nix-community.github.io/home-manager/options.html)
- [Darwin Configuration Options](https://daiderd.com/nix-darwin/manual/index.html)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)

### Community

- [NixOS Discourse](https://discourse.nixos.org/)
- [Nix-darwin GitHub](https://github.com/LnL7/nix-darwin)
- [Home-manager GitHub](https://github.com/nix-community/home-manager)

## Rollback Procedures

If something goes wrong:

```bash
# List all generations
darwin-rebuild --list-generations

# Rollback to previous
darwin-rebuild --rollback

# Switch to specific generation
darwin-rebuild switch --switch-generation 42
```

Always keep your configuration in git to enable easy recovery!