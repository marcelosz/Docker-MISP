# Docker-MISP
[![Build Status](https://travis-ci.org/marcelosz/Docker-MISP.svg?branch=master)](https://travis-ci.org/marcelosz/Docker-MISP)
![Docker Image CI](https://github.com/marcelosz/Docker-MISP/workflows/Docker%20Image%20CI/badge.svg)
[![Docker Build Status](https://img.shields.io/docker/build/marcelosz/misp.svg)](https://hub.docker.com/r/marcelosz/misp/)

The files in this repository are used to create a Docker container running a [MISP](http://www.misp-project.org) ("Malware Information Sharing Platform") instance.

## Building your image

### Fetch files
```
$ git clone https://github.com/MISP/misp-docker
$ cd misp-docker
# Copy template.env to .env (on the root directory) and edit the environment variables at .env file
$ cp template.env .env
$ vi .env
```

### Run containers
```
$ docker-compose up
```
