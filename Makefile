REPO     := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
STOW_DIR := $(shell dirname "$(REPO)")
PACKAGE  := $(notdir $(REPO))

.PHONY: help bootstrap stow unstow restow dry-run adopt adopt-cp check

help: ## show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

bootstrap: ## install stow and all mise-managed tools (run once on a new machine)
	@echo "==> stow"
	@if ! command -v stow >/dev/null 2>&1; then \
		case "$$(uname)" in \
			Darwin) brew install stow ;; \
			Linux) \
				if   command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y stow; \
				elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y stow; \
				elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm stow; \
				else echo "error: unsupported package manager — install stow manually"; exit 1; fi ;; \
			*) echo "error: unsupported OS: $$(uname) — install stow manually and re-run"; exit 1 ;; \
		esac; \
	else echo "     already installed"; fi
	@echo ""
	@echo "==> mise install"
	@if ! command -v mise >/dev/null 2>&1; then \
		echo "     mise not found — installing"; \
		curl https://mise.run | sh; \
		export PATH="$$HOME/.local/bin:$$PATH"; \
	else echo "     already installed"; fi; \
	mise install --cd "$(REPO)"
	@echo ""
	@echo "==> done"
	@echo "==> next: run 'make stow' to link your dotfiles"

stow: ## link dotfiles, restore copy-managed files, install git hooks
	@echo "==> stow: linking managed files into $$HOME"
	@cd "$(STOW_DIR)" && stow -t "$$HOME" "$(PACKAGE)"
	@echo ""
	@echo "==> cp: restoring copy-managed files"
	@while IFS= read -r rel || [ -n "$$rel" ]; do \
		case "$$rel" in ''|\#*) continue ;; esac; \
		src="$(REPO)/$$rel"; dst="$$HOME/$$rel"; \
		if [ ! -f "$$src" ]; then echo "     skip (not in repo): $$rel"; continue; fi; \
		mkdir -p "$$(dirname "$$dst")"; \
		cp "$$src" "$$dst"; \
		echo "     $$rel"; \
	done < "$(REPO)/scripts/app-files"
	@echo ""
	@echo "==> lefthook: installing git hooks"
	@if command -v lefthook >/dev/null 2>&1; then \
		cd "$(REPO)" && lefthook install; \
	else echo "     lefthook not found — skipping (run 'mise install' first)"; fi
	@echo ""
	@echo "==> done"

unstow: ## remove all managed symlinks from home
	@cd "$(STOW_DIR)" && stow -D -t "$$HOME" "$(PACKAGE)"

restow: ## unstow then re-stow (after adding or removing files from the repo)
	@$(MAKE) unstow
	@$(MAKE) stow

dry-run: ## preview what stow would change — no modifications made
	@cd "$(STOW_DIR)" && stow -nv -t "$$HOME" "$(PACKAGE)"

adopt: ## adopt a conflicting file into the repo (symlink mode)
	@"$(REPO)/scripts/adopt.sh"

adopt-cp: ## adopt a conflicting file into the repo (copy mode — for tools that don't support symlinks)
	@"$(REPO)/scripts/adopt.sh" --cp

check: ## check for drift in copy-managed configs
	@"$(REPO)/scripts/check-app-configs.sh"
