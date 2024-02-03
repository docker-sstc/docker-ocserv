#!/bin/bash

CONF_FILE=./src/ocserv.conf
SAMPLE_CONF_URL="https://gitlab.com/openconnect/ocserv/-/raw/master/doc/sample.config?ref_type=heads&inline=false"
# SAMPLE_CONF_URL="https://github.com/iw4p/OpenConnect-Cisco-AnyConnect-VPN-Server-OneKey-ocserv/raw/master/ocserv.conf"

wget "$SAMPLE_CONF_URL" -O - | grep -o '^[^#]*' > ${CONF_FILE}
sed -i '/^auth =.*$/d' $CONF_FILE
sed -i '/^server-cert =.*$/d' $CONF_FILE
sed -i '/^server-key =.*$/d' $CONF_FILE
sed -i '/^ca-cert =.*$/d' $CONF_FILE
sed -i '/^dns =.*$/d' $CONF_FILE
sed -i '/^route =.*$/d' $CONF_FILE
sed -i '/^no-route =.*$/d' $CONF_FILE

sed -i '/^try-mtu-discovery =.*$/d' $CONF_FILE
# sed -i '/^cisco-client-compat =.*$/d' $CONF_FILE
# sed -i '/^dtls-legacy =.*$/d' $CONF_FILE
sed -i '/^cisco-svc-client-compat =.*$/d' $CONF_FILE
sed -i '/^client-bypass-protocol =.*$/d' $CONF_FILE
sed -i '/^camouflage =.*$/d' $CONF_FILE
sed -i '/^camouflage_secret =.*$/d' $CONF_FILE
sed -i '/^camouflage_realm =.*$/d' $CONF_FILE

sed -i '/\[vhost:www.example.com\]/,$d' $CONF_FILE

cat ocserv-*.conf >> $CONF_FILE
