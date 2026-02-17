# Multi-Host Nix Configuration: Research, Decisions, and Plan

> **Date**: 2026-02-17
> **Author**: Luis Urraca + Claude
> **Repo**: [lurraca/kickstart.nix](https://github.com/lurraca/kickstart.nix)
> **Status**: Planning — work will be done incrementally

---

## Table of Contents

1. [Current State](#1-current-state)
2. [Target State](#2-target-state)
3. [Research: Multi-Host Patterns](#3-research-multi-host-patterns)
4. [Research: Ecosystem Tools](#4-research-ecosystem-tools)
5. [x86_64-darwin Deprecation](#5-x86_64-darwin-deprecation)
5b. [WSL2 Ubuntu: Nix on Windows](#5b-wsl2-ubuntu-nix-on-windows)
6. [Decisions Made](#6-decisions-made)
7. [Restructuring Plan](#7-restructuring-plan)
8. [Changes Already Applied](#8-changes-already-applied)
9. [Work Remaining](#9-work-remaining)
10. [Reference Repositories](#10-reference-repositories)

---

## 1. Current State

### Machines

| Machine | Hostname | Platform | Role | Priority |
|---|---|---|---|---|
| Work MacBook | `X7X56XWY9W` | `aarch64-darwin` | Primary dev machine (Zendesk) | **Now** (already managed) |
| Personal PC (WSL2) | TBD | `x86_64-linux` | Personal dev via Windows WSL2 Ubuntu | **Next** |
| Personal Mac | TBD | `x86_64-darwin` | Personal use (Intel — see [section 5](#5-x86_64-darwin-deprecation)) | **Later** |
| VPS | TBD | `x86_64-linux` | Server | **Later** |

### Current Directory Structure

```
/etc/nix-darwin/
├── flake.nix                  # Flake entry point (wiring only)
├── flake.lock                 # Pinned inputs (updated 2026-02-16)
├── darwin.nix                 # Legacy/unused (pre-flake import)
├── module/
│   ├── configuration.nix      # System-level config (single host)
│   └── home-manager.nix       # All user config in one 287-line file
├── lib/
│   └── homebrew.nix           # Declarative Homebrew (brews, casks, taps)
├── examples/                  # Untracked reference files
├── docs/
│   ├── ALIASES.md
│   ├── TROUBLESHOOTING.md
│   └── MULTI-HOST-PLAN.md     # This file
├── restructure.sh             # Legacy restructuring script
├── Makefile
├── CLAUDE.md
├── CONTRIBUTING.md
└── README.md
```

### Current Flake Inputs (as of 2026-02-16)

| Input | Source | Pinned Date |
|---|---|---|
| nixpkgs | `github:NixOS/nixpkgs/nixpkgs-unstable` | 2026-02-15 |
| nix-darwin | `github:nix-darwin/nix-darwin/master` | 2026-02-12 |
| home-manager | `github:nix-community/home-manager` | 2026-02-16 |

### Current Limitations

- **Single host only**: `darwinConfigurations."X7X56XWY9W"` — adding a second machine means duplicating or adding conditionals.
- **Monolithic home-manager**: All 287 lines in one file (shell, git, editor, terminal, tmux, starship, aliases, packages).
- **No secrets management**: No encrypted secrets in the repo.
- **No remote deployment**: No tooling for managing the VPS.
- **Darwin-specific only**: No NixOS support in the flake.
- **Hardcoded paths**: `brew shellenv` path, kubectl config path, flake hostname in aliases.
- **Legacy files**: `darwin.nix`, `restructure.sh`, `examples/` are dead weight.

---

## 2. Target State

A single flake that manages:

- **Work Mac** (`aarch64-darwin`): Full development environment with Zendesk-specific tooling via nix-darwin + home-manager
- **Personal PC / WSL2** (`x86_64-linux`): Personal dev environment via standalone home-manager on Ubuntu WSL2
- **Personal Mac** (`x86_64-darwin` now, likely `x86_64-linux` or `aarch64-darwin` later): Personal apps and dev tools
- **VPS** (`x86_64-linux`): Server services, minimal CLI tools via NixOS

With:

- Shared home-manager modules across all hosts
- Per-host overrides for machine-specific config
- Secrets management for SSH keys, API tokens, etc.
- Remote deployment capability for the VPS
- Clean separation of concerns (shell, editor, git, etc. in separate files)
- Three flake output types: `darwinConfigurations` (macOS), `nixosConfigurations` (NixOS), `homeConfigurations` (standalone HM for non-NixOS Linux)

### Target Directory Structure

```
/etc/nix-darwin/
├── flake.nix                      # Host registry + mkSystem calls
├── flake.lock
├── lib/
│   └── mkSystem.nix               # Factory function (darwin vs nixos)
├── hosts/
│   ├── work-mac/
│   │   └── default.nix            # Work Mac system config + hostname
│   ├── personal-mac/
│   │   └── default.nix            # Personal Mac system config
│   └── vps/
│       ├── default.nix            # VPS NixOS system config
│       └── hardware-configuration.nix
├── home/
│   ├── shared/                    # Applied to ALL hosts
│   │   ├── cli.nix                # bat, ripgrep, jq, eza, bottom, wget, etc.
│   │   ├── git.nix                # git + delta + gh
│   │   ├── shell.nix              # zsh, starship, zoxide, hstr, oh-my-zsh
│   │   ├── editor.nix             # neovim
│   │   └── tmux.nix               # tmux + tmuxinator
│   ├── darwin/                    # macOS-only HM modules
│   │   ├── packages.nix           # GUI apps: raycast, discord, slack, etc.
│   │   └── terminal.nix           # alacritty config
│   ├── linux/                     # Linux-only HM modules
│   │   └── packages.nix
│   ├── work.nix                   # Work-specific: kubectl aliases, saml2aws, etc.
│   ├── personal.nix               # Personal-specific
│   ├── work-mac.nix               # Entry point: imports shared + darwin + work
│   ├── wsl.nix                    # Entry point: imports shared + linux + personal
│   ├── personal-mac.nix           # Entry point: imports shared + darwin + personal
│   └── vps.nix                    # Entry point: imports shared + linux
├── modules/
│   ├── darwin/
│   │   ├── common.nix             # Shared macOS system config (fonts, shells)
│   │   └── homebrew.nix           # Homebrew declarations (moved from lib/)
│   ├── nixos/
│   │   └── common.nix             # Shared NixOS system config
│   └── shared/
│       └── nix-settings.nix       # Nix daemon config (both platforms)
├── secrets/                       # sops-nix encrypted secrets (future)
│   ├── .sops.yaml
│   └── secrets.yaml
├── overlays/
│   └── default.nix                # Custom package overlays (future)
└── docs/
    ├── ALIASES.md
    ├── TROUBLESHOOTING.md
    └── MULTI-HOST-PLAN.md         # This file
```

---

## 3. Research: Multi-Host Patterns

### Pattern Comparison

We evaluated three main approaches used across the top multi-host nix repos on GitHub (48 repos with 200+ stars surveyed, 42 actively maintained).

#### Pattern A: Raw Flake + Helper Functions

**Used by**: [mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) (2,883 stars), [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) (3,380 stars), [AlexNabokikh/nix-config](https://github.com/AlexNabokikh/nix-config) (372 stars), [malob/nix-config](https://github.com/malob/nix-config) (450 stars)

A `mkSystem` function in `lib/` handles the darwin-vs-nixos branching:

```nix
# lib/mkSystem.nix
name: { system, user, darwin ? false }:
let
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem
               else inputs.nixpkgs.lib.nixosSystem;
  hmModule = if darwin then inputs.home-manager.darwinModules.home-manager
             else inputs.home-manager.nixosModules.home-manager;
in systemFunc {
  inherit system;
  modules = [
    ../hosts/${name}
    hmModule { home-manager.users.${user} = import ../home/${name}.nix; }
  ];
}
```

Then `flake.nix` becomes a clean registry:

```nix
darwinConfigurations.work-mac = mkSystem "work-mac" { system = "aarch64-darwin"; user = "luis.urraca"; darwin = true; };
nixosConfigurations.vps       = mkSystem "vps"       { system = "x86_64-linux";  user = "luis"; };
```

**Pros**: Transparent, no extra dependencies, easy to understand and debug.
**Cons**: Manual wiring per host, more boilerplate than alternatives.

#### Pattern B: numtide/blueprint (Convention-over-Configuration)

**Source**: [numtide/blueprint](https://github.com/numtide/blueprint)
**Introduced**: 2025

Directory names map directly to flake outputs:

```
hosts/work-mac/darwin-configuration.nix  → darwinConfigurations.work-mac
hosts/vps/configuration.nix              → nixosConfigurations.vps
```

The entire `flake.nix` reduces to:

```nix
{ outputs = inputs: inputs.blueprint { inherit inputs; }; }
```

**Pros**: Almost zero boilerplate, directory-driven, built-in template for "NixOS and Darwin Shared Homes."
**Cons**: Newer (less battle-tested), magic mapping can be harder to debug.

#### Pattern C: flake-parts + ez-configs

**Used by**: [srid/nixos-config](https://github.com/srid/nixos-config) (571 stars), [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) (639 stars, uses lite-system)

Uses the NixOS module system for flake outputs:

```nix
imports = [ inputs.ez-configs.flakeModule ];
ezConfigs = { root = ./.; globalArgs = { inherit inputs; }; };
# Reads from darwin-configurations/, nixos-configurations/, home-configurations/
```

**Pros**: Full module system, option types, strong reusability, good for large setups.
**Cons**: Steeper learning curve, extra abstraction.

### Decision

**We chose Pattern A (Raw Flake + Helper Functions)** — see [section 6](#6-decisions-made) for rationale.

### Home-Manager Module Patterns

All top repos split home-manager into composable modules. Two approaches dominate:

#### Features/Imports per Host (Misterio77 pattern)

Source: [Misterio77/nix-config](https://github.com/Misterio77/nix-config) (1,213 stars)

Each host has an entry file that imports what it needs:

```nix
# home/work-mac.nix
{ ... }: { imports = [ ./shared/cli.nix ./shared/git.nix ./shared/shell.nix ./darwin/packages.nix ./work.nix ]; }

# home/vps.nix
{ ... }: { imports = [ ./shared/cli.nix ./shared/git.nix ./shared/shell.nix ./linux/packages.nix ]; }
```

#### Base Layers (ryan4yin pattern)

Source: [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) (1,805 stars)

```
home/base/core/   # Applies everywhere (git, shells, editors)
home/base/tui/    # Terminal tools (cloud, containers, dev)
home/base/gui/    # Desktop apps (only imported on desktop hosts)
```

#### Platform Conditionals

Used universally across repos for packages that differ by OS:

```nix
home.packages = with pkgs; [
  git ripgrep fd bat       # universal
] ++ lib.optionals stdenv.isDarwin [
  raycast discord slack
] ++ lib.optionals stdenv.isLinux [
  htop strace
];
```

---

## 4. Research: Ecosystem Tools

### Tool Status (as of 2026-02-17)

All tools below are actively maintained.

| Tool | Stars | Last Commit | Version | Purpose |
|---|---|---|---|---|
| [home-manager](https://github.com/nix-community/home-manager) | 9,373 | 2026-02-16 | Rolling | User environment management |
| [nix-darwin](https://github.com/nix-darwin/nix-darwin) | 5,079 | 2026-02-12 | Rolling | macOS system configuration |
| [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) | 2,863 | 2026-02-01 | v1.13.0 | Remote NixOS installation via SSH |
| [disko](https://github.com/nix-community/disko) | 2,857 | 2026-02-17 | v1.13.0 | Declarative disk partitioning |
| [sops-nix](https://github.com/Mic92/sops-nix) | 2,612 | 2026-02-15 | Rolling | Secrets management (SOPS-based) |
| [nh](https://github.com/nix-community/nh) | 2,397 | 2026-02-17 | Rolling | Better CLI for nixos-rebuild/darwin-rebuild |
| [agenix](https://github.com/ryantm/agenix) | 2,216 | 2026-02-04 | v0.15.0 | Secrets management (age-based) |
| [stylix](https://github.com/nix-community/stylix) | 2,139 | 2026-02-17 | Rolling | Declarative theming across hosts |
| [colmena](https://github.com/zhaofengli/colmena) | 2,010 | 2025-11-01 | v0.4.0 | Remote NixOS deployment |
| [deploy-rs](https://github.com/serokell/deploy-rs) | 1,986 | 2026-02-02 | Rolling | Remote NixOS deployment |
| [flake-parts](https://github.com/hercules-ci/flake-parts) | 1,210 | 2026-02-02 | Rolling | Module system for flakes |
| [nix-homebrew](https://github.com/zhaofengli/nix-homebrew) | 626 | 2026-01-26 | Rolling | Declarative Homebrew installation |
| [Lix](https://github.com/lix-project/lix) | 528 | 2026-02-17 | v2.94.0 | CppNix fork (correctness focus) |
| [mac-app-util](https://github.com/hraban/mac-app-util) | 410 | 2025-12-27 | Rolling | Fix Spotlight for Nix apps |

### Secrets: sops-nix vs agenix

| Aspect | sops-nix (2,612 stars) | agenix (2,216 stars) |
|---|---|---|
| Encryption backends | age, GPG, AWS KMS, GCP KMS, Azure KV | age only |
| Secret format | Single YAML/JSON file, multiple secrets | One file per secret |
| macOS support | Yes (caveats with launchd) | Yes (caveats with launchd) |
| Complexity | More features, more config | Simpler mental model |
| Adoption trend | Growing faster | Stable |

Sources:
- [sops-nix on macOS discussion](https://discourse.nixos.org/t/agenix-sops-nix-on-macos/47863)
- [Secret management with sops-nix (2025 guide)](https://michael.stapelberg.ch/posts/2025/08/24/secret-management-with-sops-nix/)
- [NixOS Wiki: Comparison of secret managing schemes](https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes)

### Remote Deployment: deploy-rs vs colmena

| Aspect | deploy-rs (1,986 stars) | colmena (2,010 stars) |
|---|---|---|
| Last commit | 2026-02-02 | 2025-11-01 |
| Language | Rust | Rust |
| Flake support | Native | Yes |
| Parallel deploy | Yes | Yes (+ tagging) |
| Activity | More active | Slowing down |

For initial VPS provisioning: **nixos-anywhere** (2,863 stars) + **disko** (2,857 stars).
For ongoing updates: **deploy-rs** (more actively maintained).
For simple setups: `nixos-rebuild --target-host` may suffice.

### flake-parts vs flake-utils vs Raw Flake

Source: [Nix flake-parts, flake-utils or neither? (2026-02-01)](https://www.mccurdyc.dev/posts/2026/02/nix-flake-parts-flake-utils-or-neither/index.html)

| Aspect | Raw Flake | flake-utils (1,554 stars) | flake-parts (1,210 stars) |
|---|---|---|---|
| Complexity | Minimal | Light abstraction | Full module system |
| Multi-host | Manual helpers | `eachDefaultSystem` (packages only) | ez-configs, lite-system |
| Learning curve | Lowest | Low | Medium |
| Trend | Stable | Stable, not growing | Growing adoption |

Key insight from the community: `nixosConfigurations` and `darwinConfigurations` are **not per-system outputs** — they don't benefit from `flake-utils`' `eachDefaultSystem`. For multi-host management, the choice is between raw helpers and flake-parts.

Source: [NixOS Discourse — How to make one flake.nix for multiple hosts](https://discourse.nixos.org/t/how-to-make-one-flake-nix-for-multiple-hosts/62056)

### Notable Recent Changes

#### nix-darwin (2025-2026)

- **`system.primaryUser` required** (Jan 2025): All activation runs as root. Must be set explicitly.
  Source: [nix-darwin changelog](https://github.com/nix-darwin/nix-darwin/blob/master/CHANGELOG), [Issue #1462](https://github.com/nix-darwin/nix-darwin/issues/1462)
- **Default config path**: Now `/etc/nix-darwin` for `system.stateVersion >= 6` (Jan 2025).
- **Homebrew module refresh** (Feb 2026): `brewPrefix` → `prefix`, new shell integration options, new entry types (`goPackages`, `cargoPackages`, `vscode`).

#### home-manager (2025-2026)

- **25.11**: `targets.darwin.copyApps.enable` defaults to `true` — apps copied to `~/Applications/Home Manager Apps`, fixing Spotlight without `mac-app-util`.
  Source: [home-manager release notes](https://nix-community.github.io/home-manager/release-notes.xhtml)
- **25.11**: New `home-manager switch --rollback` and `--specialisation` options.
- **25.11**: `programs.git.signing.format` no longer defaults to "openpgp" — must be set explicitly if used.
- **26.05 (unstable)**: `programs.zsh.dotDir` defaults to XDG config directory.

#### Nixpkgs (2025-2026)

- **25.11**: Minimum macOS raised to Sonoma 14.0. Default Darwin SDK now 14.4.
- **25.11**: Darwin switched to system libc++ (better compatibility).
- **25.11**: x86_64-darwin deprecation announced for 26.11. See [section 5](#5-x86_64-darwin-deprecation).
  Source: [nixpkgs 25.11 release notes](https://github.com/NixOS/nixpkgs/blob/master/doc/release-notes/rl-2511.section.md)

---

## 5. x86_64-darwin Deprecation

### The Announcement

From the **nixpkgs 25.11 release notes** ([source](https://github.com/NixOS/nixpkgs/blob/master/doc/release-notes/rl-2511.section.md)):

> "**We expect to drop support for `x86_64-darwin` by Nixpkgs 26.11,** in light of Apple's announcement that macOS 26 will be the final version to support Intel Macs. When support is fully removed, we will no longer build packages for the platform or guarantee that it can build at all. This may happen in stages, depending on our available build and maintenance resources and decisions made by projects we rely on."

### What "Dropping Support" Means

- **No Hydra builds**: No pre-built binary cache from `cache.nixos.org` for Intel Mac. Everything must compile from source (hours of builds).
- **No CI testing**: ofBorg stops testing x86_64-darwin. PRs won't be validated against Intel Mac.
- **No channel blocking**: Broken Intel Mac builds won't prevent channel advances.
- **No maintenance obligation**: The platform may break at any time.
- **Not removed from nixpkgs**: The system string still exists, but nothing guarantees it works.

### Timeline

| Date | Event | Source |
|---|---|---|
| **Jun 2025** | Apple announces macOS 26 Tahoe is last Intel macOS | [9to5mac](https://9to5mac.com/2025/06/09/apple-will-end-support-for-intel-macs/) |
| **Sep 2025** | macOS 26 Tahoe released (only 4 Intel models) | Apple |
| **Nov 2025** | Nixpkgs 25.11 announces x86_64-darwin deprecation | [release notes](https://github.com/NixOS/nixpkgs/blob/master/doc/release-notes/rl-2511.section.md) |
| **Now** | x86_64-darwin is Tier 2, everything works | — |
| **Sep 2026** | Homebrew moves Intel to Tier 3 (no bottles, no CI) | [Homebrew Support Tiers](https://docs.brew.sh/Support-Tiers#tier-3) |
| **Nov 2026** | Nixpkgs **expected** to drop x86_64-darwin | release notes |
| **Fall 2027** | GitHub Actions retires Intel macOS CI runners | [GitHub issue](https://github.com/opentoonz/opentoonz/issues/6132) |
| **Sep 2027** | Homebrew fully drops Intel | Homebrew |
| **~2028** | Apple stops security updates for macOS 26 Tahoe | Apple |

### Nixpkgs Platform Tiers (RFC 0046)

Source: [RFC 0046](https://github.com/NixOS/rfcs/blob/master/rfcs/0046-platform-support-tiers.md)

- **Tier 1** (full support, channel-blocking): `x86_64-linux`
- **Tier 2** (limited support, investigated): `aarch64-linux`, `aarch64-darwin`, **`x86_64-darwin` (current)**
- **Tier 3** (community-maintained, may break): various
- **Post-26.11**: `x86_64-darwin` drops to Tier 5-7 or full removal

### Other Ecosystem Positions

| Entity | Intel Mac Status | Source |
|---|---|---|
| **Determinate Nix** | Already dropped (< 0.01% usage) | [Blog](https://determinate.systems/blog/changelog-determinate-nix-3132/) |
| **nix-darwin** | No statement, follows nixpkgs | [README](https://github.com/nix-darwin/nix-darwin) |
| **MacPorts** | "Will likely continue for a long time" | nixpkgs 25.11 release notes |

### Options for the Personal Intel Mac

| Option | Description | Pros | Cons |
|---|---|---|---|
| **Install NixOS** | Wipe macOS, install NixOS Linux on the hardware | Full Tier 1 support forever. Same flake as VPS. Recommended by nixpkgs. | Lose macOS-specific apps (iMessage, AirDrop, etc.) |
| **Replace hardware** | Buy Apple Silicon Mac | Full ecosystem support. Same nix-darwin config as work Mac. | Costs money. |
| **Pin nixpkgs** | Stay on 26.05 (last pre-drop release), don't update | Free, no hardware changes. | Frozen packages, no security updates, increasingly stale. |
| **Standalone HM** | Drop nix-darwin, use home-manager only with selective source builds | Partial Nix management, lightweight. | Fragile, slow builds, no system-level management. |

### Recommendation

The nixpkgs release notes themselves recommend either NixOS or migrating to Apple Silicon:

> "We also recommend users consider installing NixOS, which should continue to run on essentially all Intel Macs, especially after Apple stops security support for macOS 26 in 2028."

For the multi-host flake, this is handled naturally by the `mkSystem` factory — if/when the personal Mac switches to NixOS, swap `darwinConfigurations` to `nixosConfigurations` with the same shared home-manager modules.

---

## 5b. WSL2 Ubuntu: Nix on Windows

### Context

The personal PC runs Windows with WSL2. The goal is to manage the Linux user environment (shell, git, editor, tmux, CLI tools) declaratively from the same flake as the macOS hosts.

### Two Approaches Evaluated

#### Option A: Ubuntu WSL2 + Standalone home-manager

Install the Nix daemon on top of the default Ubuntu WSL2 distro, then use `home-manager switch` to manage the user environment. The flake produces a `homeConfigurations` output.

- **Manages**: user packages, dotfiles, shell config, git, neovim, tmux, starship
- **Does NOT manage**: system packages, services, the Ubuntu base (those stay under `apt`)
- **Flake output**: `homeConfigurations."luis@wsl"`
- **Apply command**: `home-manager switch --flake <path>#luis@wsl`
- **Pattern used by**: [malob/nix-config](https://github.com/malob/nix-config) (450 stars) — `darwinConfigurations` for macOS + `homeConfigurations` for Linux

**Installation steps** (based on [Using Nix on Windows the Right Way](https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki)):

1. Install WSL2: `wsl --install` in PowerShell (reboot)
2. Inside Ubuntu, install Nix daemon:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   . /etc/profile.d/nix.sh
   ```
3. Enable flakes (add to `~/.config/nix/nix.conf`):
   ```
   experimental-features = nix-command flakes
   ```
4. Clone the flake repo and run:
   ```bash
   nix run home-manager -- switch --flake .#luis@wsl
   ```

**Gotchas**:
- Work in the Linux filesystem (`/home/luis/`), not `/mnt/c/` — the Windows-Linux filesystem bridge is slow.
- The Nix daemon install requires `--daemon` for multi-user mode.
- VS Code Remote - WSL extension provides seamless editing from Windows.

#### Option B: NixOS-WSL (Replace Ubuntu with NixOS)

[NixOS-WSL](https://github.com/nix-community/NixOS-WSL) (~1,900 stars, actively maintained) replaces the Ubuntu distro entirely with NixOS running under WSL2.

- **Manages**: everything (system + user), same as nix-darwin on macOS
- **Flake output**: `nixosConfigurations.wsl`
- **Apply command**: `sudo nixos-rebuild switch --flake <path>#wsl`

```nix
# Example flake.nix addition
inputs.nixos-wsl.url = "github:nix-community/NixOS-WSL/main";

nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    inputs.nixos-wsl.nixosModules.default
    { wsl.enable = true; wsl.defaultUser = "luis"; }
    home-manager.nixosModules.home-manager
    { home-manager.users.luis = import ./home/wsl.nix; }
  ];
};
```

### Comparison

| | Standalone HM on Ubuntu (Option A) | NixOS-WSL (Option B) |
|---|---|---|
| System management | No (Ubuntu/apt manages) | Yes (Nix manages everything) |
| Consistency with other hosts | Partial (user-level only) | Full (same as VPS pattern) |
| Setup effort | Lower (install Nix on existing Ubuntu) | Higher (import new WSL distro) |
| Flake output | `homeConfigurations` | `nixosConfigurations` |
| Can manage services | No | Yes (systemd) |
| Familiarity | Ubuntu is familiar | NixOS learning curve |
| Migration path | Can switch to NixOS-WSL later | Already there |
| Extra flake input | None | `nixos-wsl` |

### Decision

**We chose Option A: Ubuntu WSL2 + Standalone home-manager.**

**Rationale**:
- Lower friction to get started — just install Nix on existing Ubuntu.
- The primary goal is sharing dotfiles/shell/editor config, not managing the WSL system layer.
- Ubuntu is familiar and well-documented for WSL2.
- Can migrate to NixOS-WSL later if system-level management becomes desirable.
- No extra flake input needed (home-manager is already an input).
- The `homeConfigurations` pattern is well-established ([malob/nix-config](https://github.com/malob/nix-config)).

### What the WSL Host Gets from the Shared Flake

**Shared with macOS** (via `home/shared/`):
- zsh + oh-my-zsh + syntax highlighting + autosuggestions
- starship prompt (catppuccin theme)
- git + delta + gh
- neovim
- tmux
- bat, ripgrep, jq, eza, bottom, direnv, hstr, zoxide, wget

**WSL-specific** (via `home/wsl.nix` or `home/personal.nix`):
- Different git email (personal vs work)
- No Homebrew (Linux)
- No GUI macOS apps (no alacritty, raycast, etc.)
- No work-specific aliases (no kubectl, ric, drc/drs)
- Possibly different `initContent` for zsh (no `brew shellenv`)

**Not managed by Nix** (stays under Ubuntu/apt):
- System packages (unless needed)
- systemd services
- Kernel, networking, WSL interop

### Flake Output

```nix
# In flake.nix
homeConfigurations."luis@wsl" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [ ./home/wsl.nix ];
};
```

### Sources

- [Using Nix on Windows the Right Way](https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki) — basic Nix-on-WSL2 setup guide
- [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) — NixOS as a WSL distro (Option B, not chosen but documented for future reference)
- [malob/nix-config](https://github.com/malob/nix-config) — reference for `darwinConfigurations` + `homeConfigurations` pattern
- [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) — manages NixOS + Darwin + WSL from one flake (uses NixOS-WSL)

---

## 6. Decisions Made

### Decision 1: Use Raw Flake + `mkSystem` Helper (Pattern A)

**Chosen over**: numtide/blueprint (Pattern B), flake-parts + ez-configs (Pattern C)

**Rationale**:
- We have 3 hosts. Pattern A is the most popular and transparent for this scale.
- mitchellh/nixos-config (2,883 stars) is the closest match to our use case (macOS + Linux from one flake).
- No extra flake inputs needed (no blueprint, no flake-parts dependency).
- Easy to debug — all wiring is explicit Nix.
- Can migrate to flake-parts later if complexity warrants it.

### Decision 2: Use sops-nix for Secrets (When Needed)

**Chosen over**: agenix

**Rationale**:
- More stars (2,612 vs 2,216), growing faster.
- Single YAML file for all secrets (vs one-file-per-secret in agenix).
- Supports multiple encryption backends (age, GPG, cloud KMS) — useful if we ever need cloud-hosted secrets.
- Community recommendation from the [May 2025 Callista guide](https://callistaenterprise.se/blogg/teknik/2025/05/28/nix-darwin/).

### Decision 3: Use deploy-rs for VPS Deployment (When Needed)

**Chosen over**: colmena, `nixos-rebuild --target-host`

**Rationale**:
- More actively maintained than colmena (last commit 2026-02-02 vs 2025-11-01).
- Native flake support.
- For initial provisioning: nixos-anywhere + disko first, then deploy-rs for ongoing updates.

### Decision 4: Split home-manager into Composable Modules

**Pattern**: Features/imports per host (Misterio77 style)

**Rationale**:
- Current monolithic 287-line file is hard to maintain and impossible to share across hosts with different needs.
- Each host gets an entry file that imports exactly what it needs.
- New hosts only import what's relevant (e.g., VPS doesn't need GUI apps).

### Decision 5: No Flake Utility Libraries

**Not using**: flake-utils, flake-parts

**Rationale**:
- `nixosConfigurations`/`darwinConfigurations` are not per-system outputs — `eachDefaultSystem` doesn't help.
- For 3 hosts, the manual wiring is minimal and fully transparent.
- Aligns with the [2026 community consensus](https://www.mccurdyc.dev/posts/2026/02/nix-flake-parts-flake-utils-or-neither/index.html): "Use flake-parts if you plan to pull pieces of your flake into reusable modules, otherwise it's likely unnecessary."

### Decision 6: Keep Homebrew for macOS GUI Apps and Work-Specific Tools

**Rationale**:
- Many work tools (zendesk taps, docker, 1password, etc.) are only available via Homebrew.
- GUI apps work better via Homebrew casks than nixpkgs on macOS.
- nix-darwin's homebrew module handles this declaratively.
- May add [nix-homebrew](https://github.com/zhaofengli/nix-homebrew) (626 stars) later to declaratively manage the Homebrew installation itself.

### Decision 7: Use Standalone home-manager on Ubuntu WSL2 (Not NixOS-WSL)

**Chosen over**: NixOS-WSL

**Rationale**:
- Lower friction — install Nix on existing Ubuntu, no distro replacement.
- Primary goal is sharing dotfiles/shell config, not managing WSL system layer.
- Ubuntu is familiar and well-documented for WSL2.
- No extra flake input needed.
- Can migrate to NixOS-WSL later if needed.
- See [section 5b](#5b-wsl2-ubuntu-nix-on-windows) for full analysis.

---

## 7. Restructuring Plan

### Phase 1: Split home-manager.nix (Do First)

No new flake inputs needed. Pure reorganization of existing config.

1. Create `home/shared/cli.nix` — extract: bat, bottom, eza, jq, ripgrep, direnv, hstr, zoxide
2. Create `home/shared/git.nix` — extract: programs.git, programs.delta, programs.gh
3. Create `home/shared/shell.nix` — extract: programs.zsh, programs.starship, sessionVariables
4. Create `home/shared/editor.nix` — extract: programs.neovim
5. Create `home/shared/tmux.nix` — extract: programs.tmux, xdg tmuxinator config
6. Create `home/darwin/packages.nix` — extract: GUI apps (discord, slack, raycast, jetbrains, zoom, etc.)
7. Create `home/darwin/terminal.nix` — extract: programs.alacritty
8. Create `home/work.nix` — extract: work-specific aliases (kubectl, ric, drc/drs), work packages (saml2aws, stern, awscli2, ssm-session-manager-plugin)
9. Create `home/work-mac.nix` — entry point that imports all of the above
10. Update `flake.nix` to use `home/work-mac.nix` instead of `module/home-manager.nix`
11. Delete `module/home-manager.nix`

**Test**: Run `drs` to verify no regressions.

### Phase 2: Create `mkSystem` Factory + Hosts Directory

1. Create `lib/mkSystem.nix` — factory function with `darwin` flag
2. Create `hosts/work-mac/default.nix` — extract from `module/configuration.nix`: hostname, fonts, user config
3. Create `modules/darwin/common.nix` — shared macOS system config (zsh.enable, nix settings)
4. Create `modules/shared/nix-settings.nix` — nix daemon config (works on both platforms)
5. Move `lib/homebrew.nix` → `modules/darwin/homebrew.nix`
6. Update `flake.nix` to use `mkSystem`
7. Delete `module/configuration.nix`, old `lib/homebrew.nix`

**Test**: Run `drs` to verify no regressions.

### Phase 3: Add WSL2 Host (Standalone home-manager)

Prerequisites: Phase 1 complete (shared modules exist).

**On the Windows PC:**

1. Install WSL2: `wsl --install` in PowerShell, reboot
2. Install Nix daemon inside Ubuntu:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   . /etc/profile.d/nix.sh
   ```
3. Enable flakes in `~/.config/nix/nix.conf`:
   ```
   experimental-features = nix-command flakes
   ```
4. Clone the flake repo:
   ```bash
   git clone git@github.com:lurraca/kickstart.nix.git ~/nix-config
   ```

**In the flake repo:**

5. Create `home/personal.nix` — personal-specific config (git email, personal aliases)
6. Create `home/linux/packages.nix` — Linux-only CLI packages
7. Create `home/wsl.nix` — entry point that imports shared + linux + personal:
   ```nix
   { pkgs, ... }: {
     imports = [
       ./shared/cli.nix
       ./shared/git.nix
       ./shared/shell.nix
       ./shared/editor.nix
       ./shared/tmux.nix
       ./linux/packages.nix
       ./personal.nix
     ];

     home.username = "luis";
     home.homeDirectory = "/home/luis";
     home.stateVersion = "23.11";
     programs.home-manager.enable = true;
   }
   ```
8. Add `homeConfigurations` output to `flake.nix`:
   ```nix
   homeConfigurations."luis@wsl" = home-manager.lib.homeManagerConfiguration {
     pkgs = nixpkgs.legacyPackages.x86_64-linux;
     modules = [ ./home/wsl.nix ];
   };
   ```
9. Handle platform differences in shared modules:
   - `home/shared/shell.nix`: guard `brew shellenv` with `lib.optionals pkgs.stdenv.isDarwin`
   - `home/shared/shell.nix`: make `drc`/`drs` aliases darwin-only
   - `home/personal.nix`: set personal git email instead of work email

**On the WSL2 machine:**

10. Apply the configuration:
    ```bash
    cd ~/nix-config
    nix run home-manager -- switch --flake .#luis@wsl
    ```

**Test**: Verify shell, git, neovim, tmux, starship all work correctly inside WSL2.

**Gotchas**:
- Always work in `/home/luis/`, not `/mnt/c/` (filesystem bridge is slow)
- The `oh-my-zsh` plugins and Homebrew-specific shell init must be guarded with platform conditionals
- `programs.home-manager.enable = true` is required for standalone HM (already in shared config but verify)
- First run uses `nix run home-manager --` because HM isn't installed yet; subsequent runs use `home-manager switch`

### Phase 4: Add Personal Mac (Later)

1. Create `hosts/personal-mac/default.nix`
2. Create `home/personal-mac.nix` — imports shared + darwin + personal
3. Reuse `home/personal.nix` (same personal config as WSL)
4. Add `darwinConfigurations.personal-mac` to `flake.nix`
5. Handle `x86_64-darwin` vs `aarch64-darwin` in system config
6. Consider x86_64-darwin deprecation timeline (see [section 5](#5-x86_64-darwin-deprecation))

### Phase 5: Add VPS (NixOS)

1. Add nixpkgs `nixosConfigurations` output support to `flake.nix`
2. Create `hosts/vps/default.nix` + `hardware-configuration.nix`
3. Create `modules/nixos/common.nix`
4. Create `home/vps.nix` — imports shared + linux
5. Use nixos-anywhere + disko for initial provisioning
6. Set up deploy-rs for ongoing updates

### Phase 6: Add Secrets Management

1. Add `sops-nix` to flake inputs
2. Create `secrets/.sops.yaml` with key-to-secret mapping
3. Create `secrets/secrets.yaml` with encrypted secrets
4. Derive age keys from SSH keys via `ssh-to-age`
5. Integrate secrets into per-host configs as needed

### Phase 7: Cleanup

1. Delete `darwin.nix` (legacy pre-flake import)
2. Delete `restructure.sh`
3. Delete or commit `examples/`
4. Update `README.md` with new structure
5. Consider adding `nh` (2,397 stars) as a nicer CLI for rebuild commands

---

## 8. Changes Already Applied

These changes were made on 2026-02-17 and committed as `43836d3`:

### Flake Inputs Updated
- nixpkgs: Jun 2025 → Feb 2026
- nix-darwin: Jun 2025 → Feb 2026
- home-manager: Jun 2025 → Feb 2026

### Home-Manager Migrations (Breaking Changes from Update)
- `programs.git.userEmail` → `programs.git.settings.user.email`
- `programs.git.userName` → `programs.git.settings.user.name`
- `programs.git.extraConfig` → `programs.git.settings`
- `programs.git.delta` → standalone `programs.delta` with `enableGitIntegration = true`
- `jetbrains.idea-ultimate` → `jetbrains.idea` (upstream rename)

### Config Restructuring
- Removed dead `let` block from `home-manager.nix` (stale nix-channel comments)
- Removed duplicate packages: `delta`, `amazon-ecr-credential-helper`, `ruby` (kept in Homebrew)
- Merged inline `configuration` block from `flake.nix` into `module/configuration.nix`
- Passed `self` to modules via `specialArgs = { inherit self; }` instead of inline flake config
- Removed unused `pkgs.vim` from system packages
- Removed empty `system = {};` block

### New Additions
- `programs.tmux.tmuxinator.enable = true`
- `xdg.configFile."tmuxinator/work.yml"` — declarative tmuxinator layout
- `CLAUDE_CODE_DISABLE_AUTO_MEMORY = "0"` session variable
- `superclaude` alias
- `brew shellenv` in zsh `initContent`
- Fixed `drc`/`drs` aliases to correct flake path (`/etc/nix-darwin#X7X56XWY9W`)
- Starship scala module disabled (JVM cold-start timeout fix)
- New Homebrew packages: bun, cursor, cursor-cli, docker, sbt, openjdk@21, rbenv, ruby-build, zendesk-aws-shell, logi-options-plus, zd_aws-sso, oven-sh/bun tap
- Removed `node` from Homebrew (duplicate with nixpkgs `nodejs_24`)
- Changed `openjdk` → `openjdk@21` (Java 18 was EOL)

---

## 9. Work Remaining

### Now (Can Do Immediately)

- [ ] **Phase 1**: Split `home-manager.nix` into composable modules
- [ ] **Phase 2**: Create `mkSystem` factory and `hosts/` directory
- [ ] Delete `darwin.nix` (unused legacy file)
- [ ] Delete `restructure.sh` (old script)
- [ ] Decide what to do with `examples/` directory
- [ ] Run `nix-collect-garbage -d && sudo nix-collect-garbage -d` to reclaim disk space

### Next (WSL2 Setup)

- [ ] **Phase 3**: Set up WSL2 Ubuntu on personal PC
- [ ] **Phase 3**: Install Nix daemon on WSL2
- [ ] **Phase 3**: Create `home/wsl.nix`, `home/personal.nix`, `home/linux/packages.nix`
- [ ] **Phase 3**: Add `homeConfigurations."luis@wsl"` to `flake.nix`
- [ ] **Phase 3**: Add platform conditionals to shared modules (guard brew shellenv, darwin-only aliases)
- [ ] **Phase 3**: Apply and test on WSL2

### Later

- [ ] **Phase 4**: Add personal Mac configuration (x86_64-darwin)
- [ ] **Phase 5**: Add VPS NixOS configuration
- [ ] **Phase 6**: Add sops-nix secrets management
- [ ] **Phase 7**: Final cleanup and documentation

### Before Nov 2026 (x86_64-darwin Deadline)

- [ ] Decide personal Mac fate: NixOS install, hardware replacement, or pin nixpkgs
- [ ] If NixOS: test NixOS installation on Intel Mac hardware
- [ ] If replacement: buy Apple Silicon Mac, update flake to `aarch64-darwin`

### Optional Enhancements

- [ ] Add `nh` CLI (2,397 stars) for better rebuild UX
- [ ] Add `nix-homebrew` (626 stars) to declaratively manage Homebrew installation
- [ ] Add `stylix` (2,139 stars) for consistent theming across hosts
- [ ] Evaluate Determinate Nix's native Linux builder for cross-platform builds on macOS
- [ ] Migrate WSL2 from Ubuntu + standalone HM to NixOS-WSL (if system-level management becomes desirable)

---

## 10. Reference Repositories

### Best Multi-Host Examples (Darwin + Linux, Actively Maintained)

| Repo | Stars | Platforms | Pattern | Why Relevant |
|---|---|---|---|---|
| [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) | 3,380 | macOS + NixOS | Platform-split with shared modules | Starter template, well documented |
| [mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) | 2,883 | macOS + NixOS VMs | `mkSystem` factory | Closest to our chosen pattern |
| [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | 1,805 | macOS + NixOS + homelab | Per-architecture outputs, layered home | Advanced multi-arch example |
| [Veraticus/nix-config](https://github.com/Veraticus/nix-config) | 824 | Mac laptop + Linux servers | Unified flake | Similar use case to ours |
| [MatthiasBenaets/nix-config](https://github.com/MatthiasBenaets/nix-config) | 727 | NixOS + nix-darwin | Delegated imports | Clean module organization |
| [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) | 639 | NixOS + Darwin + WSL | Type-based registry | Most comprehensive multi-platform |
| [srid/nixos-config](https://github.com/srid/nixos-config) | 571 | NixOS + macOS | flake-parts + nixos-unified | Alternative (flake-parts) approach |
| [kclejeune/system](https://github.com/kclejeune/system) | 513 | NixOS + Darwin + HM | Unified | Clean and minimal |
| [malob/nix-config](https://github.com/malob/nix-config) | 450 | Darwin + Linux HM-only | `mkDarwinSystem` + `homeConfigurations` | macOS-focused with Linux HM standalone |
| [AlexNabokikh/nix-config](https://github.com/AlexNabokikh/nix-config) | 372 | NixOS + Darwin + HM | `mkNixosConfiguration`/`mkDarwinConfiguration` helpers | Clean helper function pattern |
| [NobbZ/nixos-config](https://github.com/NobbZ/nixos-config) | 265 | x86_64-linux + aarch64-linux + aarch64-darwin | Multi-arch | 3 architectures from one flake |
| [alyraffauf/nixcfg](https://github.com/alyraffauf/nixcfg) | 212 | NixOS + Darwin + HM | Multi-host | Explicitly labeled multi-host |

### Starter Templates

| Repo | Stars | Description |
|---|---|---|
| [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) | 3,577 | Official-quality templates for NixOS + HM + flakes |
| [ryan4yin/nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter) | 636 | Beginner-friendly nix-darwin + HM template |
| [ALT-F4-LLC/kickstart.nix](https://github.com/ALT-F4-LLC/kickstart.nix) | 213 | Multi-platform starter |

### Guides and Blog Posts (2025-2026)

| Title | Date | URL |
|---|---|---|
| Using Nix on Windows the Right Way | 2025 | [dev.to](https://dev.to/jajera/using-nix-on-windows-the-right-way-14ki) |
| NixOS meets MacOS (Callista) | May 2025 | [callistaenterprise.se](https://callistaenterprise.se/blogg/teknik/2025/05/28/nix-darwin/) |
| Next Step in Nix: Flakes and Home Manager | Apr 2025 | [callistaenterprise.se](https://callistaenterprise.se/blogg/teknik/2025/04/10/nix-flakes/) |
| Nix: structuring Flakes with Blueprint | Feb 2025 | [bmcgee.ie](https://bmcgee.ie/posts/2025/02/nix-structuring-flakes-with-blueprint/) |
| Nix flake-parts, flake-utils or neither? | Feb 2026 | [mccurdyc.dev](https://www.mccurdyc.dev/posts/2026/02/nix-flake-parts-flake-utils-or-neither/index.html) |
| Secret management with sops-nix | Aug 2025 | [stapelberg.ch](https://michael.stapelberg.ch/posts/2025/08/24/secret-management-with-sops-nix/) |

### WSL2 / Linux References

| Repo/Resource | Description |
|---|---|
| [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) | NixOS as a WSL2 distro (~1,900 stars). Not chosen now but documented as future migration path. |
| [malob/nix-config](https://github.com/malob/nix-config) | Reference for `darwinConfigurations` + `homeConfigurations` pattern (450 stars) |
| [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) | Manages NixOS + Darwin + WSL from one flake (639 stars) |

### Community Discussions

| Topic | URL |
|---|---|
| How to make one flake.nix for multiple hosts | [NixOS Discourse](https://discourse.nixos.org/t/how-to-make-one-flake-nix-for-multiple-hosts/62056) |
| How do you keep multiple hosts in sync? | [NixOS Discourse](https://discourse.nixos.org/t/how-do-you-go-about-keeping-multiple-hosts-in-sync/37439) |
| Pattern: every file is a flake-parts module | [NixOS Discourse](https://discourse.nixos.org/t/pattern-every-file-is-a-flake-parts-module/61271) |
| agenix/sops-nix on macOS | [NixOS Discourse](https://discourse.nixos.org/t/agenix-sops-nix-on-macos/47863) |
| Darwin SDKs updated | [NixOS Discourse](https://discourse.nixos.org/t/the-darwin-sdks-have-been-updated/55295) |
| flake-utils vs flake-parts | [Reddit r/NixOS](https://www.reddit.com/r/NixOS/comments/1avlimn/who_wins_flakeutils_vs_flakeparts_vs_custom_nix/) |
