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
        echo "[*] Fixing permissions..."
        echo "[-] INFO: chown -R www-data.www-data /var/www/MISP ..." && find /var/www/MISP -not -user www-data -exec chown www-data.www-data {} +
        echo "[-] INFO: chmod -R 0750 /var/www/MISP ..." && find /var/www/MISP -perm 550 -type f -exec chmod 0550 {} + && find /var/www/MISP -perm 770 -type d -exec chmod 0770 {} +
        echo "[-] INFO: chmod -R g+ws /var/www/MISP/app/tmp ..." && chmod -R g+ws /var/www/MISP/app/tmp
        echo "[-] INFO: chmod -R g+ws /var/www/MISP/app/files ..." && chmod -R g+ws /var/www/MISP/app/files
        echo "[-] INFO: chmod -R g+ws /var/www/MISP/app/files/scripts/tmp ..." && chmod -R g+ws /var/www/MISP/app/files/scripts/tmp
        echo "[-] INFO: chmod +x /var/www/MISP/app/Console/cake ..." && chmod +x /var/www/MISP/app/Console/cake
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
                postconf -e "relayhost = $POSTFIX_RELAY_HOST"
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
        while ! mysqladmin ping -h"$MYSQL_HOST" -u"$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" --silent; do
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
        echo "[*] Adjusting MISP configuration..."
        echo "[-] INFO: Setting base config..."        
        MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
        cd $MISP_APP_CONFIG_PATH
        # Adjust permissions on this file
        touch config.php.bk
        chown www-data.www-data config.php.bk
        cp -a database.default.php database.php
        sed -i "s/localhost/$MYSQL_HOST/" database.php
        sed -i "s/db\s*login/$MYSQL_USER/" database.php
        sed -i "s/8889/3306/" database.php
        sed -i "s/db\s*password/$MYSQL_PASSWORD/" database.php

        if [ -z "$MISP_BASEURL" ]; then
                echo "[-] INFO: No base URL defined, don't forget to define it manually!"
        else
                echo "[-] Fixing the MISP base URL ($MISP_BASEURL)..."
                sed -i "s/'baseurl' => '',/'baseurl' => '$MISP_BASEURL',/" $MISP_APP_CONFIG_PATH/config.php
                /var/www/MISP/app/Console/cake Admin setSetting "MISP.baseurl" "$MISP_BASEURL"       
                /var/www/MISP/app/Console/cake Admin setSetting "MISP.external_baseurl" "$MISP_BASEURL"
        fi

        echo "[-] INFO: Setting Redis FQDN..."
        [ -z "$REDIS_FQDN" ] && REDIS_FQDN=misp_redis
        sed -i "s/'host' => 'localhost'.*/'host' => '$REDIS_FQDN',          \/\/ Redis server hostname/" "/var/www/MISP/app/Plugin/CakeResque/Config/config.php"
        /var/www/MISP/app/Console/cake Admin setSetting "MISP.redis_host" "$REDIS_FQDN"

        echo "[-] INFO: PyMISP workaround..."
        # Work around https://github.com/MISP/MISP/issues/5608
        if [[ ! -f /var/www/MISP/PyMISP/pymisp/data/describeTypes.json ]]; then
                mkdir -p /var/www/MISP/PyMISP/pymisp/data/
                ln -s /usr/local/lib/python3.7/dist-packages/pymisp/data/describeTypes.json /var/www/MISP/PyMISP/pymisp/data/describeTypes.json
        fi

        # Other settings
        echo "[-] INFO: Adjusting other MISP settings..."
        /var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" $(which python3)

        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_url" "http://misp_modules"
        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_enable" true
        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_hover_enable" true        

        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_url" "http://misp_modules"
        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_enable" true

        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_url" "http://misp_modules"
        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_enable" true

        /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Cortex_services_enable" false

        /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.email" "$MISP_ADMIN_EMAIL"
        /var/www/MISP/app/Console/cake Admin setSetting "GnuPG.homedir" "/var/www/MISP"

        ln -sf /var/www/MISP/app/tmp/logs /var/log/misp

        # Create MISP cron tab
        echo "[-] INFO: Creating Cron entries for MISP in /etc/cron.d/misp..."
        CRON_USER_ID=1
        cat << EOF > /var/www/MISP/misp.cron
# Admin tasks - update components
00 3 * * * www-data /var/www/MISP/app/Console/cake Admin updateGalaxies >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
10 3 * * * www-data /var/www/MISP/app/Console/cake Admin updateTaxonomies >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
20 3 * * * www-data /var/www/MISP/app/Console/cake Admin updateWarningLists >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
30 3 * * * www-data /var/www/MISP/app/Console/cake Admin updateNoticeLists >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
45 3 * * * www-data /var/www/MISP/app/Console/cake Admin updateObjectTemplates >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
# Fetch feeds - a job for each feed
# TODO - Adjust these entries as needed. Double check to see if the feed IDs match.
15 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 1 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
20 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 2 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
25 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 3 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
30 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 4 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
35 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 5 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
40 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 6 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
45 *    * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 7 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
# Phishtank fetch job is less frequent - due to Phishtank limit
50 */2  * * *   root    /var/www/MISP/app/Console/cake Server fetchFeed "$CRON_USER_ID" 8 >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
# Cache all feeds
55 *    * * *   root    /var/www/MISP/app/Console/cake Server cacheFeed "$CRON_USER_ID" all >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
# TODO - Sync servers - uncomments these as needed
#00 0 * * * www-data /var/www/MISP/app/Console/cake Server pull "$CRON_USER_ID" "$SYNCSERVER" >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
#05 1 * * * www-data /var/www/MISP/app/Console/cake Server push "$CRON_USER_ID" "$SYNCSERVER" >>/var/log/misp-cron.log 2>>/var/log/misp-cron.log
EOF
        ln -sf /var/www/MISP/misp.cron /etc/cron.d/misp
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
1) Adjust Base URL setting
2) Check relay host $POSTFIX_RELAY_HOST SMTP settings
3) Change the MISP admin email address to $MISP_ADMIN_EMAIL
4) Check cron settings (/etc/cron.d/misp) for the admin tasks and feeds fetching as needed
5) Do the fine tunning of your new MISP instance (organization name, users, sync user & servers, plugins, proxy, ...)

__WELCOME__
        rm -f /.firstboot.tmp
fi

# Start rsyslog, cron and postfix
service rsyslog start
service cron start
service postfix start

# Start supervisord
echo "[*] Starting supervisord..."
cd /
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
