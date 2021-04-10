.PHONY: layer-zip layer-upload layer-publish func-zip create-func update-func layer-all func-all invoke clean

LAYER_NAME ?= eks-kubectl-layer
LAYER_DESC ?= eks-kubectl-layer
S3BUCKET ?= lambda-eks-helm-deployment
LAMBDA_REGION ?= us-east-1
LAMBDA_FUNC_NAME ?= lambda-eks-helm-deployment
CLUSTER_NAME ?= default

GLOBAL_REGIONS ?= us-east-1 eu-west-1 eu-central-1

SEMANTIC_VERSION ?= 3.2.0

.PHONY: sam-package
sam-package:
	@docker run -t \
	-v $(PWD):/home/samcli/workdir \
	-v $(HOME)/.aws:/root/.aws \
	-w /home/samcli/workdir \
	-u root \
	-e AWS_DEFAULT_PROFILE \
	-e AWS_CONTAINER_CREDENTIALS_RELATIVE_URI \
	pahud/aws-sam-cli:latest sam package --template-file sam.yaml \
	--s3-bucket $(S3BUCKET) --output-template-file packaged.yaml \
	--region $(LAMBDA_REGION)
	@echo "[OK] Now type 'make sam-deploy' to deploy your Lambda layer with SAM or 'make publish-new-version-to-sar' to publish to SAR"

.PHONY: sam-publish
sam-publish:
	@docker run -i $(EXTRA_DOCKER_ARGS) \
	-v $(PWD):/home/samcli/workdir \
	-v $(HOME)/.aws:/root/.aws \
	-w /home/samcli/workdir \
	-u root \
	-e AWS_DEFAULT_PROFILE \
	-e AWS_CONTAINER_CREDENTIALS_RELATIVE_URI \
	pahud/aws-sam-cli:latest sam publish --region $(LAMBDA_REGION) --template packaged.yaml \
	--semantic-version $(SEMANTIC_VERSION)
	@echo "=> version $(SEMANTIC_VERSION) published to $(LAMBDA_REGION)"

put-policy:
	@aws serverlessrepo put-application-policy \
		--region us-east-1 \
		--application-id arn:aws:serverlessrepo:us-east-1:213096763263:applications/lambda-eks-helm-deployment \
		--statements Principals=485994781579,Actions=Deploy

deploy:
	@docker run -t \
	-v $(PWD):/home/samcli/workdir \
	-v $(HOME)/.aws:/root/.aws \
	-w /home/samcli/workdir \
	-u root \
	-e AWS_DEFAULT_PROFILE \
	-e AWS_CONTAINER_CREDENTIALS_RELATIVE_URI \
	pahud/aws-sam-cli:latest sam deploy --s3-bucket juratherm-sam \
		--stack-name TestRepo12 \
		--region eu-central-1 \
		--template-file ./samples/lambda.yaml \
		--capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND
