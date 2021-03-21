# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Production Image
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM pennsieve/base-processor-java-python:6-43b7408 as build

ARG NXF_VER

RUN apk add -v --update --no-cache \
                       ca-certificates \
                       coreutils \
                       curl \
                       openssl

# taken from nextflow dockerfile: https://github.com/nextflow-io/nextflow/blob/master/docker/Dockerfile
ENV NXF_OPTS='-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap'

# used by the get.nextflow.io script to know which nextflow version to install
ENV NXF_VER=$NXF_VER

RUN pip install requests && \
    cd /usr/bin && wget -q -O nextflow https://get.nextflow.io && \
    chmod +x nextflow && \
    ./nextflow info

WORKDIR /usr/src/nextflow

COPY run_nextflow.py ./
COPY nextflow.config ./
COPY workflows       ./workflows
COPY registry.py     ./

ENTRYPOINT ["python"]
CMD ["run_nextflow.py"]


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Test Image
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

FROM build as test

# for tests --------------------------------------
RUN apk add -v --update --no-cache \
    py-pip python-dev gcc libffi-dev libressl-dev musl-dev && \
    pip install moto==1.3.1 botocore==1.12.91 pytest requests
# ------------------------------------------------

ENTRYPOINT ["python"]
CMD ["-m", "pytest", "--capture=sys", "-v", "tests/"]
