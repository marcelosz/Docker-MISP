#
# Dockerfile to build a MISP (https://github.com/MISP/MISP) container
#
ARG MISP_TAG=v2.4.124
ARG MODULES_TAG=v2.4.121
ARG PHP_VER=20180731

#
# Composer build
#
FROM composer:1.9 as composer-build
    ARG MISP_TAG
    WORKDIR /tmp
    ADD https://raw.githubusercontent.com/MISP/MISP/${MISP_TAG}/app/composer.json /tmp
    RUN composer install --ignore-platform-reqs

#
# PHP build
#
FROM debian:buster-slim as php-build
    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        make \
        libfuzzy-dev \
        ca-certificates \
        php \
        php-dev \
        php-pear \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
    RUN cp /usr/lib/x86_64-linux-gnu/libfuzzy.* /usr/lib; pecl install ssdeep
        
#
# Python build
# 
FROM debian:buster-slim as python-build
    RUN apt-get update; apt-get install -y --no-install-recommends \
        gcc \
        git \
        python3 \
        python3-dev \
        python3-setuptools \
        python3-wheel \
        libfuzzy-dev \
        ca-certificates \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN mkdir /wheels

    WORKDIR /tmp
    RUN git clone --depth 1 https://github.com/CybOXProject/mixbox.git; \
        cd mixbox || exit; python3 setup.py bdist_wheel -d /wheels

    # install python-maec
    RUN git clone --depth 1 https://github.com/MAECProject/python-maec.git; \
        cd python-maec || exit; python3 setup.py bdist_wheel -d /wheels

    # install python-cybox
    RUN git clone --depth 1 https://github.com/CybOXProject/python-cybox.git; \
        cd python-cybox || exit; python3 setup.py bdist_wheel -d /wheels

    # install python stix
    RUN git clone --depth 1 https://github.com/STIXProject/python-stix.git; \
        cd python-stix || exit; python3 setup.py bdist_wheel -d /wheels

    # install STIX2.0 library to support STIX 2.0 export:
    RUN git clone --depth 1 https://github.com/MISP/cti-python-stix2.git; \
        cd cti-python-stix2 || exit; python3 setup.py bdist_wheel -d /wheels

    # install PyMISP
    RUN git clone --depth 1 https://github.com/MISP/PyMISP.git; \
        cd PyMISP || exit; python3 setup.py bdist_wheel -d /wheels

    # install pydeep
    RUN git clone --depth 1 https://github.com/coolacid/pydeep.git; \
        cd pydeep || exit; python3 setup.py bdist_wheel -d /wheels

#
# MISP modules build
#
FROM python:3.7-slim-buster as modules-build
ENV DEBIAN_FRONTEND noninteractive
ARG MODULES_TAG

    RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        git \
        python3-dev \
        python3-pip \
        python3-wheel \
        build-essential \
        pkg-config \
        libpoppler-cpp-dev \
        libfuzzy-dev \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN mkdir /wheel
    WORKDIR /srv
    RUN git clone --branch ${MODULES_TAG} --depth 1  https://github.com/MISP/misp-modules.git /srv/misp-modules; \
        cd /srv/misp-modules || exit; sed -i 's/-e //g' REQUIREMENTS; pip3 wheel -r REQUIREMENTS --no-cache-dir -w /wheel/

    RUN git clone --depth 1 https://github.com/stricaud/faup.git /srv/faup; \
        cd /srv/faup/build || exit; cmake .. && make install; \
        cd /srv/faup/src/lib/bindings/python || exit; pip3 wheel --no-cache-dir -w /wheel/ .

############################################################################################################################

#
# Main install
#
FROM debian:buster-slim
ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.UTF-8
ARG MISP_TAG
ARG MISP_MODULES
ARG PHP_VER

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    gpg-agent gpg \
    openssl \
    sudo \
    vim \
    zip \
    locales \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

#
# Apache, PHP and Python
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Apache
    apache2 \
    apache2-doc \
    apache2-utils \
    # PHP Requirements
    php \
    php-xml \
    php-mbstring \
    php-mysql \
    php-redis \
    php-gd \
    # Python Requirements
    python3 \
    python3-setuptools \
    python3-pip \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN a2dismod status
RUN a2dissite 000-default

#
# Other tools
#
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    redis-server \
    postfix \    
    cron \
    logrotate \
    syslog-ng-core \
    ssdeep \
    libfuzzy2 \    
    mariadb-client \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* 

#
# Install Python Modules
#
COPY --from=python-build /wheels /wheels
RUN pip3 install --no-cache-dir /wheels/*.whl plyara pyzmq redis python-magic lief && rm -rf /wheels

#
# Install MISP Modules
#
RUN apt-get update && apt-get install -y --no-install-recommends \
            libglib2.0-0 \
            libzbar0 \
            libxrender1 \
            libxext6 \
            libpoppler-cpp0v5 \
            && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
COPY --from=modules-build /wheel /wheel
COPY --from=modules-build /usr/local/lib/libfaupl* /usr/local/lib/
RUN pip3 install /wheel/*.whl; ldconfig

#
# Download, install and configure MISP itself
#
WORKDIR /var/www
RUN chown www-data:www-data /var/www
USER www-data
# If we specify --branch we won't be able to update MISP from the UI "Server Settings & Maintenance"
#RUN git clone --branch ${MISP_TAG} --depth 1 https://github.com/MISP/MISP.git
RUN git clone https://github.com/MISP/MISP.git
WORKDIR /var/www/MISP
RUN git submodule update --init --recursive ;
RUN git submodule foreach --recursive git config core.filemode false ;
RUN git config core.filemode false ;

USER root
# Install ssdeep prebuild, latest composer, then install the app's PHP deps
COPY --from=php-build /usr/lib/php/${PHP_VER}/ssdeep.so /usr/lib/php/${PHP_VER}/ssdeep.so
COPY --from=composer-build /tmp/Vendor /var/www/MISP/app/Vendor
COPY --from=composer-build /tmp/Plugin /var/www/MISP/app/Plugin
RUN for dir in /etc/php/*; do echo "extension=ssdeep.so" > "$dir/mods-available/ssdeep.ini"; done \
    ;phpenmod redis \
# Enable CakeResque with php-gnupgp
    ;phpenmod gnupg \
# Enable ssdeep we build earlier
    ;phpenmod ssdeep \
# To use the scheduler worker for scheduled tasks, do the following:
    ;cp -fa /var/www/MISP/INSTALL/setup/config.php /var/www/MISP/app/Plugin/CakeResque/Config/config.php

USER www-data
WORKDIR /var/www/MISP
RUN git submodule init
RUN git submodule update
WORKDIR /var/www/MISP/app

USER root
RUN cp /var/www/MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp

# Preconfigure setting for packages
RUN echo "postfix postfix/main_mailer_type string Local only" | debconf-set-selections
RUN echo "postfix postfix/mailname string localhost.localdomain" | debconf-set-selections

# Redis Setup
RUN sed -i 's/^\(daemonize\s*\)yes\s*$/\1no/g' /etc/redis/redis.conf

# Apache Setup
RUN cp /var/www/MISP/INSTALL/apache.misp.ubuntu /etc/apache2/sites-available/misp.conf
RUN a2dissite 000-default
RUN a2ensite misp
RUN a2enmod rewrite
RUN a2enmod headers

# MISP base configuration
RUN cp -a /var/www/MISP/app/Config/bootstrap.default.php /var/www/MISP/app/Config/bootstrap.php
RUN cp -a /var/www/MISP/app/Config/database.default.php /var/www/MISP/app/Config/database.php
RUN cp -a /var/www/MISP/app/Config/core.default.php /var/www/MISP/app/Config/core.php
RUN cp -a /var/www/MISP/app/Config/config.default.php /var/www/MISP/app/Config/config.php

# Replace the default salt
RUN sed -i -E "s/'salt'\s=>\s'(\S+)'/'salt' => '`openssl rand -base64 32|tr "/" "-"`'/" /var/www/MISP/app/Config/config.php

# Install templates & stuff
WORKDIR /var/www/MISP/app/files
RUN rm -rf misp-objects && git clone https://github.com/MISP/misp-objects.git
RUN rm -rf misp-galaxy && git clone https://github.com/MISP/misp-galaxy.git
RUN rm -rf warninglists && git clone https://github.com/MISP/misp-warninglists.git ./warninglists
RUN rm -rf taxonomies && git clone https://github.com/MISP/misp-taxonomies.git ./taxonomies

#
# Supervisord conf file
#
COPY files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Modify syslog configuration
RUN sed -i -E 's/^(\s*)system\(\);/\1unix-stream("\/dev\/log");/' /etc/syslog-ng/syslog-ng.conf

# Trigger to perform first boot operations
RUN touch /.firstboot.tmp

# Make a backup of /var/www/MISP to restore it to the local mount point at first boot
WORKDIR /var/www/MISP
RUN tar czpf /root/MISP.tgz .

COPY files/entrypoint.sh /
RUN chmod 0755 /entrypoint.sh

COPY files/entrypoint_workers.sh /
RUN chmod 0755 /entrypoint_workers.sh

HEALTHCHECK --interval=5m --timeout=3s \
    CMD curl -f http://localhost/ || exit 1

VOLUME /var/www/MISP
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
