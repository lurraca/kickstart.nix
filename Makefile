# Nix-darwin Makefile
# Convenience commands for common operations

HOSTNAME := X7X56XWY9W
FLAKE := .#$(HOSTNAME)

.PHONY: help
help: ## Show this help message
	@echo "Nix-darwin configuration management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

.PHONY: switch
switch: ## Build and switch to new configuration
	darwin-rebuild switch --flake $(FLAKE)

.PHONY: build
build: ## Build configuration without switching
	darwin-rebuild build --flake $(FLAKE)

.PHONY: check
check: ## Check configuration for errors
	darwin-rebuild check --flake $(FLAKE)

.PHONY: update
update: ## Update all flake inputs
	nix flake update

.PHONY: update-nixpkgs
update-nixpkgs: ## Update only nixpkgs input
	nix flake lock --update-input nixpkgs

.PHONY: update-darwin
update-darwin: ## Update only nix-darwin input
	nix flake lock --update-input nix-darwin

.PHONY: update-home-manager
update-home-manager: ## Update only home-manager input
	nix flake lock --update-input home-manager

.PHONY: clean
clean: ## Garbage collect all old generations
	sudo nix-collect-garbage -d

.PHONY: clean-old
clean-old: ## Garbage collect generations older than 7 days
	sudo nix-collect-garbage --delete-older-than 7d

.PHONY: optimize
optimize: ## Optimize nix store
	nix-store --optimise

.PHONY: show
show: ## Show flake outputs
	nix flake show

.PHONY: repl
repl: ## Open Nix REPL with flake
	nix repl --expr 'builtins.getFlake (toString ./.)'

.PHONY: history
history: ## Show generation history
	darwin-rebuild --list-generations

.PHONY: rollback
rollback: ## Rollback to previous generation
	darwin-rebuild --rollback

.PHONY: diff
diff: ## Show what would change on switch
	@echo "Building configuration..."
	@darwin-rebuild build --flake $(FLAKE)
	@echo ""
	@echo "Differences:"
	@nix store diff-closures /run/current-system ./result

.PHONY: brew-update
brew-update: ## Update Homebrew packages
	brew update && brew upgrade

.PHONY: brew-cleanup
brew-cleanup: ## Clean up old Homebrew versions
	brew cleanup -s
	brew autoremove

.PHONY: search
search: ## Search for a package (usage: make search PKG=packagename)
	@if [ -z "$(PKG)" ]; then \
		echo "Usage: make search PKG=packagename"; \
	else \
		echo "Searching nixpkgs for '$(PKG)'..."; \
		nix search nixpkgs $(PKG); \
	fi

.PHONY: info
info: ## Show system information
	@echo "Hostname: $(HOSTNAME)"
	@echo "Flake: $(FLAKE)"
	@echo "Current generation:"
	@darwin-rebuild --list-generations | tail -1
	@echo ""
	@echo "Nix version:"
	@nix --version
	@echo ""
	@echo "Store size:"
	@du -sh /nix/store 2>/dev/null || echo "Unable to determine store size"

.PHONY: fmt
fmt: ## Format nix files
	@if command -v nixpkgs-fmt >/dev/null 2>&1; then \
		nixpkgs-fmt flake.nix module/*.nix lib/*.nix; \
	else \
		echo "nixpkgs-fmt not found. Install with: nix-env -iA nixpkgs.nixpkgs-fmt"; \
	fi

.PHONY: backup
backup: ## Create a backup tag of current configuration
	@BACKUP_TAG="backup-$$(date +%Y%m%d-%H%M%S)"; \
	git tag -a "$$BACKUP_TAG" -m "Backup before changes"; \
	echo "Created backup tag: $$BACKUP_TAG"

.PHONY: test
test: check build ## Run all tests (check and build)