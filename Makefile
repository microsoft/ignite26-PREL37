# Default configuration
ifneq ($(wildcard .lab-bundle),)
LAB_ROOT ?= $(abspath $(CURDIR)/..)
else
LAB_ROOT ?= $(HOME)/prel37
endif
LAB_SOURCE := $(CURDIR)
export LAB_ROOT LAB_SOURCE

.PHONY: setup lab-bundle machine-setup connect auth backstage argocd app reset teardown lint help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "} {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Bundle: prepare the VM; Git checkout: provision Azure and configure the lab
ifneq ($(wildcard .lab-bundle),)
	@bash setup/bundle-setup.sh
else
	@echo "Starting fast-track setup..."
	@bash setup/fast-track.sh
endif

lab-bundle: ## Package committed lab files into a temporary directory and uploadable ZIP
	@bash setup/lab-bundle.sh

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

reset: ## Remove the local workspace without destroying Azure (disabled in bundles)
ifneq ($(wildcard .lab-bundle),)
	@echo "Reset and teardown are disabled in the Skillable bundle. Skillable owns the lab lifecycle." >&2
	@exit 1
else
	@echo "Cleaning local runtime files..."
	@rm -rf $(LAB_ROOT)
	@echo "Local workspace cleaned. Your Azure infrastructure remains active."
endif

teardown: ## TOTAL WIPE: Destroy Azure and remove local files (disabled in bundles)
ifneq ($(wildcard .lab-bundle),)
	@echo "Reset and teardown are disabled in the Skillable bundle. Skillable owns the lab lifecycle." >&2
	@exit 1
else
	@echo "WARNING: This will destroy your clusters and delete all local setup configs!"
	@printf "Are you sure? (y/N) "; \
	if read -r response && [ "$$response" = "y" ]; then \
		bash setup/destroy.sh; \
	else \
		echo "Destroy cancelled."; \
	fi
endif

lint: ## Check all markdown files for style and formatting errors
	@echo "Linting markdown files..."
	@npx markdownlint-cli "**/*.md"

setup-env: ## Ensure local directories exist
	@mkdir -p $(LAB_ROOT)/config $(LAB_ROOT)/runtime
