# Docker-MISP
[![Build Status](https://travis-ci.org/marcelosz/Docker-MISP.svg?branch=master)](https://travis-ci.org/marcelosz/Docker-MISP)
![Docker Build](https://github.com/marcelosz/Docker-MISP/workflows/Docker%20Image%20CI/badge.svg)

Docker-MISP provides base files (Dockerfile, ...) for creating and running [MISP](http://www.misp-project.org) instances with simple Docker images.

Main features:
- Ready to download, deploy and use
- YAML file for 'docker-compose up', to easily deploy a MISP instance as a Docker container stack (with separate mis-modules, MySQL, Redis and Mail server containers)
- YAML file for 'docker-compose build', to help building the core MISP and the MISP Modules Docker images from scratch
- Built-in persistent volumes configuration

The main Dockerfile is already integrated to Docker Hub, so you can download images directly from [there](https://hub.docker.com/repository/docker/marcelosz/misp), simply using **marcelosz/misp:core-latest** and **marcelosz/misp:modules-latest** for example.

# Using Docker-MISP
### Deploying a new MISP instance
Clone the repository and get into its folder
```
$ git clone https://github.com/marcelosz/Docker-MISP.git
$ cd Docker-MISP
```
Copy template.env to .env and edit the environment variables as needed (related to the MISP users, passwords, SMTP settings, base URL and other settings)
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

# TODO
Please check repository [Issues](https://github.com/marcelosz/Docker-MISP/issues) for the current TODO list.


# Acknowledgements
Docker-MISP is based on previous work by Xavier Mertens (@xme) and Jason Kendall (@collacid).
