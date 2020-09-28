# Docker-MISP
[![Build Status](https://travis-ci.org/marcelosz/Docker-MISP.svg?branch=master)](https://travis-ci.org/marcelosz/Docker-MISP)
![Docker Build](https://github.com/marcelosz/Docker-MISP/workflows/Docker%20Image%20CI/badge.svg)

Docker-MISP provides base files (Dockerfile, ...) for creating and running [MISP](http://www.misp-project.org) instances with simple Docker images.

Main features:
- Ready to download, deploy and use
- YAML file for 'docker-compose up', to easily deploy a MISP instance as a Docker container stack (with separate misp-modules, MySQL, Redis and Mail server containers)
- YAML file for 'docker-compose build', to help building the core MISP and the MISP Modules Docker images from scratch
- Built-in persistent volumes configuration

The main Dockerfile is already integrated to Docker Hub, so you can download images directly from [there](https://hub.docker.com/repository/docker/marcelosz/misp), simply using **marcelosz/misp:core-latest** and **marcelosz/misp:modules-latest** for example.

## Using Docker-MISP
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
Deploy the Docker stack using docker-compose (pure Apache HTTP Server option)
```
$ docker-compose up
```
or (for a nginx reverse proxy with ModSecurity and Certbot)
```
$ docker-compose -f docker-compose-nginx.yml up
```

For instructions on how to setup MISP after installation, check https://github.com/marcelosz/Docker-MISP/wiki/How-to-install-MISP-using-Docker-MISP

### Building the core MISP Docker image
Clone the repository and get into its folder
```
$ git clone https://github.com/marcelosz/Docker-MISP.git
$ cd Docker-MISP
```
Copy template.env to .env and edit the tags (PHP_VER, MISP_TAG, MODULES_TAG) as needed (see comment below)
```
$ cp template.env .env
$ vi .env
```
Build the core Docker image
```
$ docker-compose -f docker-compose-build.yml build
```
> **Important**:
> Although a MISP_TAG variable exists, Docker-MISP does not currently uses a specific MISP version. The latest version available in the Github repository is used during image build time. On the other hand, misp-modules version is indeed enforced (based on MODULES_TAG variable).
> Docker Hub builds are based on this logic. See CHANGELOG to check the software versions used in the Docker Hub build release.

## CHANGELOG
### \[1.1.2\] - 2020-09-28
  - Port 80 is not exposed by default anymore
  - Added docker-compose-nginx.yml as an option to spin up a stack with nginx (plus ModSecurity and Certbot)
### \[1.1.1\] - 2020-09-27
  - Minor issues fixed
### \[1.1.0\] - 2020-09-26
  - MISP version updated to v2.4.132
### \[1.0.1\] - 2020-04-14
  - Minor Docker automated build issues fixed
### \[1.0.0\] - 2020-04-06
  - First production-ready release!
  - Current software versions: MISP v2.4.124 and misp-modules v2.4.121

## TODO
Please check repository [Issues](https://github.com/marcelosz/Docker-MISP/issues) for the current TODO list.


## Acknowledgements
Docker-MISP is based on previous work by Xavier Mertens (@xme) and Jason Kendall (@collacid).
