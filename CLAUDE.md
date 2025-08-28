# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a nix-darwin configuration repository for macOS system setup. It uses Nix flakes to manage system configuration, user packages, and Homebrew installations.

## Common Commands

### Building and Switching Configurations

```bash
# Check configuration for errors
darwin-rebuild check --flake ".#X7X56XWY9W"

# Apply configuration changes
darwin-rebuild switch --flake ".#X7X56XWY9W"

# Build configuration without switching
darwin-rebuild build --flake ".#X7X56XWY9W"
```

Note: The hostname `X7X56XWY9W` is defined in `flake.nix:48`.

### Nix Package Management

```bash
# Search for packages
nix-env -qaP | grep <package-name>

# Update flake inputs
nix flake update

# Show flake metadata
nix flake metadata
```

## Architecture

### Configuration Structure

1. **flake.nix**: Main entry point defining the system configuration
   - Imports nixpkgs, nix-darwin, and home-manager
   - Sets up darwinConfiguration for hostname "X7X56XWY9W"
   - Configures experimental features and platform (aarch64-darwin)

2. **module/configuration.nix**: System-level configuration
   - Nix settings (substituters, trusted users)
   - Font packages
   - User account setup
   - Shell configuration

3. **module/home-manager.nix**: User-level configuration via home-manager
   - Package installations (development tools, IDEs, utilities)
   - Program configurations (alacritty, git, tmux, zsh, etc.)
   - Shell aliases and environment variables

4. **lib/homebrew.nix**: Homebrew integration
   - Manages Homebrew packages not available in nixpkgs
   - Configures private taps (zendesk repositories)
   - Manages GUI applications via casks

### Key Design Patterns

- **Modular Configuration**: Each aspect (system, home-manager, homebrew) is separated into its own module
- **Flake-based**: Uses Nix flakes for reproducible builds and dependency management
- **Hybrid Package Management**: Combines nixpkgs packages with Homebrew for macOS-specific applications
- **User-specific Configuration**: Uses parameterized username ("luis.urraca") passed through the module system

### Development Workflow

When making changes:
1. Edit the relevant configuration file
2. Run `darwin-rebuild check --flake ".#X7X56XWY9W"` to validate
3. Run `darwin-rebuild switch --flake ".#X7X56XWY9W"` to apply changes

For package updates:
1. Update flake inputs with `nix flake update`
2. Rebuild and switch to apply updates