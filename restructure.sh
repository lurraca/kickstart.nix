#!/bin/bash
# Script to help restructure the nix-darwin configuration

echo "This script will help you restructure your nix-darwin configuration"
echo "It will create directories but won't move files automatically"
echo ""

# Create new directory structure
mkdir -p hosts/X7X56XWY9W
mkdir -p modules/darwin
mkdir -p modules/home-manager/programs
mkdir -p modules/home-manager/shell
mkdir -p modules/home-manager/development
mkdir -p modules/shared
mkdir -p overlays
mkdir -p secrets

echo "✅ Created directory structure:"
echo ""
echo "nixos-config/"
echo "├── hosts/"
echo "│   └── X7X56XWY9W/        # Host-specific config"
echo "├── modules/"
echo "│   ├── darwin/             # macOS system config"
echo "│   ├── home-manager/       # User config"
echo "│   │   ├── programs/       # Program configs"
echo "│   │   ├── shell/          # Shell setup"
echo "│   │   └── development/    # Dev tools"
echo "│   └── shared/             # Cross-platform"
echo "├── overlays/               # Package overrides"
echo "└── secrets/                # Encrypted secrets"
echo ""
echo "Next steps:"
echo "1. Move module/configuration.nix → modules/darwin/default.nix"
echo "2. Split module/home-manager.nix into smaller files"
echo "3. Move lib/homebrew.nix → modules/darwin/homebrew.nix"
echo "4. Create host-specific configuration in hosts/X7X56XWY9W/"