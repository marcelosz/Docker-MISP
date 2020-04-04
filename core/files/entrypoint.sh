#!/bin/bash
#
# MISP docker startup script
# - original version by Xavier Mertens <xavier@rootshell.be>
#

set -e

echo "[*] Starting entrypoint.sh"

if [ -r /.firstboot.tmp ]; then
        echo "[*] Container started for the fist time. Setup might time a few minutes."
        echo "[*] (Details are logged in /tmp/install.log)"
        export DEBIAN_FRONTEND=noninteractive

        # If the user uses a mount point restore our files
        if [ ! -d /var/www/MISP/app ]; then
                echo "[*] Restoring MISP files..."
                cd /var/www/MISP
                tar xzpf /root/MISP.tgz
                rm /root/MISP.tgz
        fi

        # Fix permissions


echo "Configure MISP | Enforce permissions ..."
echo "... chown -R www-data.www-data /var/www/MISP ..." && find /var/www/MISP -not -user www-data -exec chown www-data.www-data {} +
echo "... chmod -R 0750 /var/www/MISP ..." && find /var/www/MISP -perm 550 -type f -exec chmod 0550 {} + && find /var/www/MISP -perm 770 -type d -exec chmod 0770 {} +
echo "... chmod -R g+ws /var/www/MISP/app/tmp ..." && chmod -R g+ws /var/www/MISP/app/tmp
echo "... chmod -R g+ws /var/www/MISP/app/files ..." && chmod -R g+ws /var/www/MISP/app/files
echo "... chmod -R g+ws /var/www/MISP/app/files/scripts/tmp ..." && chmod -R g+ws /var/www/MISP/app/files/scripts/tmp


        echo "[*] Fixing permissions..."
        chown -R www-data:www-data /var/www/MISP
        chmod -R 750 /var/www/MISP
        chmod -R g+ws /var/www/MISP/app/tmp
        chmod -R g+ws /var/www/MISP/app/files
        chmod -R g+ws /var/www/MISP/app/files/scripts/tmp
        chmod +x /var/www/MISP/app/Console/cake
        chown -R www-data:www-data /var/www/MISP/app/Config
        chmod -R 750 /var/www/MISP/app/Config
        cd /var/www/MISP/app/files        
        chown -R www-data:www-data misp-objects misp-galaxy warninglists taxonomies

        # Fix repository permissions to allow update of submodules (objects, galaxy, taxonomies...)
        echo "[*] Updating MISP local repository and submodule permissions..."
        cd /var/www/MISP
        sudo -u www-data git pull origin 2.4
        sudo -u www-data git submodule update -f

        echo "[*] Configuring PHP recommended settings..."
        # Fix php.ini with recommended settings
        for FILE in /etc/php/*/apache2/php.ini
        do  
                [[ -e $FILE ]] || break
                sed -i "s/memory_limit = .*/memory_limit = 2048M/" "$FILE"
                sed -i "s/max_execution_time = .*/max_execution_time = 300/" "$FILE"
                sed -i "s/upload_max_filesize = .*/upload_max_filesize = 50M/" "$FILE"
                sed -i "s/post_max_size = .*/post_max_size = 50M/" "$FILE"
        done

        echo "[*] Configuring postfix and timezone..."
        if [ -z "$POSTFIX_RELAY_HOST" ]; then
                echo "[-] WARNING: Variable POSTFIX_RELAY_HOST is not set, please configure Postfix manually later..."
        else
                postconf -e "relayhost = $POSTFIX_RELAY"
        fi
        if [ -z "$TIMEZONE" ]; then
                echo "[-] WARNING: TIMEZONE is not set, please configure the local time zone manually later..."
        else
                echo "$TIMEZONE" > /etc/timezone
                dpkg-reconfigure -f noninteractive tzdata >>/tmp/install.log
        fi

        echo "[*] Creating MySQL database..."
        # Check MYSQL_HOST
        if [ -z "$MYSQL_HOST" ]; then
                echo "[-] ERROR: MYSQL_HOST is not set. Aborting."
                exit 1
        fi
		
		# Waiting for DB to be ready
		while ! mysqladmin ping -h"$MYSQL_HOST" --silent; do
		    sleep 5
			echo "[-] INFO: Waiting for database to be ready..."
		done
		
        # Set MYSQL_PASSWORD
        if [ -z "$MYSQL_PASSWORD" ]; then
                echo "[-] WARNING: MYSQL_PASSWORD is not set, use default value 'misp'"
                MYSQL_PASSWORD=misp
        else
                echo "[-] INFO: MYSQL_PASSWORD is set to '$MYSQL_PASSWORD'"
        fi

        ret=`echo 'SHOW TABLES;' | mysql -u $MYSQL_USER --password="$MYSQL_PASSWORD" -h $MYSQL_HOST -P 3306 $MYSQL_DATABASE # 2>&1`
        if [ $? -eq 0 ]; then
                echo "[-] INFO: Connected to database successfully!"
                found=0
                for table in $ret; do
                        if [ "$table" == "attributes" ]; then
                                found=1
                        fi
                done
                if [ $found -eq 1 ]; then
                        echo "[-] INFO: Database misp available"
                else
                        echo "[-] Database misp empty, creating tables ..."
                        ret=`mysql -u $MYSQL_USER --password="$MYSQL_PASSWORD" $MYSQL_DATABASE -h $MYSQL_HOST -P 3306 2>&1 < /var/www/MISP/INSTALL/MYSQL.sql`
                        if [ $? -eq 0 ]; then
                            echo "[-] INFO: Imported /var/www/MISP/INSTALL/MYSQL.sql successfully"
                        else
                            echo "[-] ERROR: Importing /var/www/MISP/INSTALL/MYSQL.sql failed:"
                            echo $ret
                        fi
                fi
        else
                echo "[-] ERROR: Connecting to database failed:"
                echo $ret
        fi

        # MISP configuration
        echo "[*] Adjusting MISP configuration files..."
        MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
        cd MISP_APP_CONFIG_PATH
        cp -a database.default.php database.php
        sed -i "s/localhost/$MYSQL_HOST/" database.php
        sed -i "s/db\s*login/$MYSQL_USER/" database.php
        sed -i "s/8889/3306/" database.php
        sed -i "s/db\s*password/$MYSQL_PASSWORD/" database.php

        # Fix the base url
        if [ -z "$MISP_BASEURL" ]; then
                echo "[-] INFO: No base URL defined, don't forget to define it manually!"
        else
                echo "[*] Fixing the MISP base URL ($MISP_BASEURL) ..."
                sed -i "s/'baseurl' => '',/'baseurl' => '$MISP_BASEURL',/" MISP_APP_CONFIG_PATH/config.php
        fi
        # Set Redis
        echo "[-] INFO: Setting Redis FQDN..."
        [ -z "$REDIS_FQDN" ] && REDIS_FQDN=misp_redis
        sed -i "s/'host' => 'localhost'.*/'host' => '$REDIS_FQDN',          \/\/ Redis server hostname/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"

        # TODO
        #echo "Configure sane defaults"
        #/var/www/MISP/app/Console/cake Admin setSetting "MISP.redis_host" "$REDIS_FQDN"
        #/var/www/MISP/app/Console/cake Admin setSetting "MISP.baseurl" "$HOSTNAME"
        #/var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" $(which python3)

        # Generate the admin user PGP key
        echo "[*] Creating admin GnuPG key..."
        if [ -z "$MISP_ADMIN_EMAIL" -o -z "$MISP_ADMIN_PASSPHRASE" ]; then
                echo "[-] No admin details provided, don't forget to generate the PGP key manually!"
        else
                echo "[-] Generating admin PGP key... (please be patient, we need some entropy)"
                cat >/tmp/gpg.tmp <<GPGEOF
%echo Generating a basic OpenPGP key
Key-Type: RSA
Key-Length: 2048
Name-Real: MISP Admin
Name-Email: $MISP_ADMIN_EMAIL
Expire-Date: 0
Passphrase: $MISP_ADMIN_PASSPHRASE
%commit
%echo Done
GPGEOF
                sudo -u www-data gpg --homedir /var/www/MISP/.gnupg --gen-key --batch /tmp/gpg.tmp >>/tmp/install.log
                rm -f /tmp/gpg.tmp
		sudo -u www-data gpg --homedir /var/www/MISP/.gnupg --export --armor $MISP_ADMIN_EMAIL > /var/www/MISP/app/webroot/gpg.asc
        fi

        # Display tips
        cat <<__WELCOME__

Congratulations!
Your MISP docker has been successfully booted for the first time.
Don't forget to:
- Reconfigure postfix to match your environment
- Change the MISP admin email address to $MISP_ADMIN_EMAIL

__WELCOME__
        rm -f /.firstboot.tmp
fi

# Start supervisord
echo "[*] Starting supervisord..."
cd /
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
