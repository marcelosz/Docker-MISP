#!/bin/bash

while true
do
    echo "Start Workers..."
    sudo -u www-data /var/www/MISP/app/Console/worker/start.sh
    echo "Start Workers...finished"
    sleep 3600
done
