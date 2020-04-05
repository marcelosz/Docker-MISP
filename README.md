# Docker-MISP
[![Build Status](https://travis-ci.org/marcelosz/Docker-MISP.svg?branch=master)](https://travis-ci.org/marcelosz/Docker-MISP)
![Docker Build](https://github.com/marcelosz/Docker-MISP/workflows/Docker%20Image%20CI/badge.svg)

Docker-MISP provides base files (Dockerfile, ...) for creating and running a [MISP](http://www.misp-project.org) instance with simple Docker images.

Main features:
- Ready to download, deploy and use
- YAML file for 'docker-compose up', to easily deploy a MISP instance as a Docker container stack (with separate MySQL, Redis and Mail server containers)
- YAML file for 'docker-compose build', to help building the core MISP Docker image from scratch
- Built-in misp-modules component
- Built-in persistent volumes configuration

The main Dockerfile is already integrated to Docker Hub, so you can download images directly from [there](https://hub.docker.com/repository/docker/marcelosz/misp). 

# Using Docker-MISP
### Deploying a new MISP instance
Clone the repository and get into its folder
```
$ git clone https://github.com/marcelosz/Docker-MISP.git
$ cd Docker-MISP
```
Copy template.env to .env and edit the environment variables as needed
```
$ cp template.env .env
$ vi .env
```
Deploy the Docker stack using docker-compose
```
$ docker-compose up
```

### Building the core MISP Docker image
Clone the repository and get into its folder
```
$ git clone https://github.com/marcelosz/Docker-MISP.git
$ cd Docker-MISP
```
Build the core Docker image
```
$ docker-compose -f docker-compose-build.yml build
```

# Acknowledgements
Docker-MISP is based on previous work by Xavier Mertens (@xme) and Jason Kendall (@collacid).
