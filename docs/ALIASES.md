# Shell Aliases and Functions Reference

This document provides a comprehensive list of all shell aliases and custom functions configured in this nix-darwin setup.

## Git Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `gbr` | `git branch` | List, create, or delete branches |
| `gci` | `git commit` | Record changes to the repository |
| `gco` | `git checkout` | Switch branches or restore files |
| `gpf` | `git push --force-with-lease` | Safely force push changes |
| `gst` | `git status` | Show working tree status |
| `gti` | `git` | Common typo correction |

## System Management

| Alias | Command | Description |
|-------|---------|-------------|
| `drc` | `darwin-rebuild check --flake ".#x86_64"` | Check nix-darwin configuration for errors |
| `drs` | `darwin-rebuild switch --flake ".#x86_64"` | Apply nix-darwin configuration changes |

## Kubernetes (k8s)

| Alias | Command | Description |
|-------|---------|-------------|
| `k` | `kubectl` | Kubernetes command-line tool |
| `ka` | `kubectl --as admin --as-group system:masters --context` | kubectl with admin privileges |
| `kc` | `kubectl --context` | kubectl with context specification |
| `kz` | `kubectl --as admin --as-group edge-infra-admin --as-group system:authenticated --namespace zorg --context` | kubectl for zorg namespace |

## File Management

| Alias | Command | Description |
|-------|---------|-------------|
| `cat` | `bat` | Enhanced cat with syntax highlighting |
| `ll` | `ls -lah` | List files in long format with hidden files |

## Development Tools

| Alias | Command | Description |
|-------|---------|-------------|
| `be` | `bundle exec` | Execute a command in the context of a bundle |
| `knife` | `be knife` | Chef knife with bundle exec |
| `t` | `tmux` | Terminal multiplexer |
| `v` | `nvim` | Neovim text editor |
| `vi` | `nvim` | Redirect vi to Neovim |
| `vim` | `nvim` | Redirect vim to Neovim |

## Docker

| Alias | Command | Description |
|-------|---------|-------------|
| `docker-machine` | `__docker_machine_wrapper` | Docker machine wrapper function |

## Oh My Zsh Plugins

The following Oh My Zsh plugins are enabled, providing additional aliases and functions:

### aliases plugin
Provides commands to list and search aliases:
- `als` - List all aliases
- `als <search>` - Search for aliases

### gh plugin
GitHub CLI integration with completions and additional commands

### git plugin
Extensive git aliases (run `alias | grep git` to see all)

### themes plugin
Theme management commands

### web-search plugin
Search various sites from the command line:
- `google <query>` - Search Google
- `github <query>` - Search GitHub
- `stackoverflow <query>` - Search Stack Overflow

### z plugin
Frecency-based directory jumping:
- `z <partial-directory-name>` - Jump to frequently/recently used directory

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `EDITOR` | `nvim` | Default text editor |
| `SHELL` | `${pkgs.zsh}/bin/zsh` | Default shell |

## Custom Functions

### Zsh Configuration

The configuration sources additional kubectl-specific functions from:
```bash
source ~/Code/zendesk/kubectl_config/dotfiles/kubectl_stuff.bash
```

### Directory Navigation

- **zoxide**: Modern replacement for `cd` with smart jumping
  - `z <partial-path>` - Jump to directory
  - `zi` - Interactive directory selection

### History Search

- **hstr**: Enhanced history search (Ctrl+R replacement)
  - `Ctrl+R` - Interactive history search
  - `hh` - Launch hstr

## Terminal Integration

### Tmux Configuration
- Prefix: `Ctrl+a` (remapped from default `Ctrl+b`)
- `Ctrl+a "` - Split window horizontally (keeps current path)
- `Ctrl+a %` - Split window vertically (keeps current path)
- Mouse mode enabled for scrolling and pane selection

### Starship Prompt
Custom prompt with:
- Git status indicators
- Command execution time
- Current directory
- Catppuccin Macchiato color scheme

## Tips

1. Use `als` to search for aliases you might have forgotten
2. The `z` command learns from your navigation patterns - use it more to improve its suggestions
3. Many git aliases from Oh My Zsh are available - run `alias | grep git` to explore
4. Use `bat` instead of `cat` for syntax-highlighted file viewing
5. `eza` is available as a modern replacement for `ls` with better defaults