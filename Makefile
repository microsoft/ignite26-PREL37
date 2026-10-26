# Default configuration
LAB_ROOT ?= $(HOME)/prel37
LAB_SOURCE := $(shell pwd)
export LAB_ROOT LAB_SOURCE

.PHONY: setup machine-setup connect auth backstage argocd app reset teardown lint help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "} {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Fast-track: Full installation (Provision Azure, Setup Repos, Install Software)
	@echo "Starting fast-track setup..."
	@bash setup/fast-track.sh

machine-setup: ## Prepare the Skillable WSL lab using pre-provisioned Azure resources
	@bash setup/machine-setup.sh

connect: ## Refresh cluster credentials and environment variables
	@echo "Bootstrapping environment..."
	@bash setup/bootstrap.sh
	@echo "Done. Remember to: source $(LAB_ROOT)/config/lab.env"

auth: ## Apply GitHub tokens to the control cluster
	@echo "Applying tokens..."
	@bash setup/apply-tokens.sh

backstage: ## Start Backstage at http://localhost:3000 (foreground)
	@bash setup/start-backstage.sh

argocd: ## Open the Argo CD UI at https://localhost:8443 (foreground)
	@bash setup/start-argocd.sh

app: ## Open the application at http://<team>.localhost:8080 through the Gateway (foreground)
	@bash setup/start-app.sh

reset: ## Remove local runtime files (does NOT destroy Azure resources)
	@echo "Cleaning local runtime files..."
	@rm -rf $(LAB_ROOT)
	@echo "Local workspace cleaned. Your Azure infrastructure remains active."

teardown: ## TOTAL WIPE: Destroys Azure resources and removes all local files
	@echo "WARNING: This will destroy your clusters and delete all local setup configs!"
	@printf "Are you sure? (y/N) "; \
	if read -r response && [ "$$response" = "y" ]; then \
		bash setup/destroy.sh; \
	else \
		echo "Destroy cancelled."; \
	fi

lint: ## Check all markdown files for style and formatting errors
	@echo "Linting markdown files..."
	@npx markdownlint-cli "**/*.md"

setup-env: ## Ensure local directories exist
	@mkdir -p $(LAB_ROOT)/config $(LAB_ROOT)/runtime
