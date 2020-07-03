.DEFAULT_GOAL := help

ENV?=dev
OWNER?=csc
REGION?=eu-west-1
TERRAFORM_STATE_BUCKET?=csc.infrastructure.$(ENV)
TERRAFORM_STATE_KEY?=terraform/security/cm/terraform.tfstate

terraform-init: ## initialize
	terraform version
	terraform init \
	 -backend-config "bucket=$(TERRAFORM_STATE_BUCKET)" \
	 -backend-config "region=$(REGION)" \
	 -backend-config "key=$(TERRAFORM_STATE_KEY)"

terraform-plan: ## Plan
	make terraform-init
	terraform plan --var-file="environments/$(ENV).tfvars"

terraform-plan-destroy: ## Plan Destroy
	make terraform-init
	terraform plan --destroy --var-file="environments/$(ENV).tfvars" -lock=false

terraform-apply: ## Apply
	make terraform-init
	terraform apply --var-file="environments/$(ENV).tfvars" -auto-approve -lock=false

terraform-destroy: ## Destroy
	make terraform-init
	terraform destroy --var-file="environments/$(ENV).tfvars" -auto-approve -lock=false

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
