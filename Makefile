PHONY: build push image ci-test ci-test-workflow- nextflow setup- clean test test-workflow- list-workflow-

TAG ?= local
BUCKET="${ENV}-etl-bucket-use1"
export NETWORK_NAME=${TAG}-etl-nextflow
export NXF_VER=18.10.1
export WORKFLOW

ifeq ($(WORKFLOW),)
    WORKFLOWS = $(shell ls workflows/*.nf | sed 's/.nf//g' | xargs -L 1 basename | xargs)
else
	WORKFLOWS = $(WORKFLOW)
endif

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Nextflow-specific
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

nextflow:
	@echo "Installing Nextflow"
	wget -q -O nextflow https://get.nextflow.io
	chmod +x nextflow
	./nextflow info

build:
	docker pull pennsieve/nextflow:latest
	docker build --target=build --build-arg NXF_VER=$(NXF_VER) \
		--cache-from pennsieve/nextflow:latest -t pennsieve/nextflow:$(TAG) .

push:
	docker push pennsieve/nextflow:$(TAG)

image: build push

test-executor:
	docker build -t pennsieve/nextflow:test . --target=test
	docker run -v $(PWD)/tests:/usr/src/nextflow/tests:ro pennsieve/nextflow:test

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Workflow-specific
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ci-test-workflow-%: build
	@$(eval inputs := $(shell ls tests/$*/inputs*.json))
	@$(foreach input, $(inputs), { $(MAKE) clean && docker run \
		--entrypoint=/usr/bin/nextflow \
		-v $$PWD/workflows:/usr/src/nextflow/workflows \
		-v $$PWD/tests:/usr/src/nextflow/tests pennsieve/nextflow:$(TAG) \
		run ./workflows/$*.nf -profile local -params-file $(input) -without-docker; } || exit 1; )

ci-test: build
	@echo "Running nextflow in docker, executing tests locally in container"
	@$(foreach WORKFLOW, $(workflows), $(MAKE) ci-test-workflow-$(WORKFLOW) || exit 1;)

list-workflows-%:
	@$(eval inputs := $(shell ls tests/$*/inputs*.json))
	@$(foreach input, $(inputs), echo "- $(input)")

test-workflow-%: nextflow
	@$(eval inputs := $(shell ls tests/$*/inputs*.json))
	$(foreach input, $(inputs), { $(MAKE) clean && $(MAKE) setup-$* && \
		./nextflow run ./workflows/$*.nf -profile local -params-file $(input); } || exit 1;)

test:
	@echo "Running local nextflow, executing tests in docker"
	docker pull pennsieve/etl-data-cli:latest
	docker pull pennsieve/channel-writer-processor:latest
	docker pull pennsieve/timeseries-exporter:latest
	docker pull pennsieve/timeseries-exporter:latest
	docker pull pennsieve/hdf5-processor:latest
	@$(foreach WORKFLOW, $(workflows), $(MAKE) test-workflow-$(WORKFLOW) || exit 1;)

info:
	@echo "WORKFLOWS:"
	@$(foreach workflow, $(WORKFLOWS), echo "  * ${workflow}";)

setup-%:
	@echo "Setting up environment to test $*: redis, postgres, and s3..."
	./local_setup.sh $*

clean:
	docker-compose down
	docker-compose rm
	@rm -rf work
	@rm -rf .nextflow
	@rm -f .nextflow.log*
