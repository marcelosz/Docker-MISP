#
# Dockerfile to build a misp-modules (https://github.com/MISP/misp-modules) container
#

#
# Build and Install MISP Modules
#
FROM python:3.7-slim-buster
ENV DEBIAN_FRONTEND noninteractive
ARG MODULES_TAG

RUN apt-get update && apt-get install -y --no-install-recommends \
    virtualenv \
    cmake \
    git \
    python3-dev \
    build-essential \
    pkg-config \
    libpoppler-cpp-dev \
    libfuzzy-dev \
    libpq5 libjpeg-dev tesseract-ocr imagemagick libopencv-dev zbar-tools libzbar0 libzbar-dev \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN git clone --branch ${MODULES_TAG} --depth 1  https://github.com/MISP/misp-modules.git /opt/misp-modules;

WORKDIR /opt/misp-modules
RUN pip3 install -I -r REQUIREMENTS
RUN pip3 install .

ENTRYPOINT [ "/opt/misp-modules/bin/misp-modules", "-l", "0.0.0.0"]
