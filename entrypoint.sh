#!/bin/sh

__err=0
function log() {
	if [ "$VERBOSE" == "true" ]; then
		printf '[sstc/ocserv] %s\n' "$@"
	fi
}
function err() {
	__err=$((__err + 1))
	printf '[sstc/ocserv] %s\n' "$@" 1>&2
}
function log_fgen() {
    log "$1 not found, auto generating..."
}
function import_v_or_die() {
    local v=$(sed $CONF_FILE -n -e "s@^\s*${2}\s*=\s*\(.*\)@\1@p")
    if [ -z "$v" ]; then
        err "$2 not found in $CONF_FILE, skipping."
        exit 2
    fi
    eval "$1=$v"
}

if [ -z "$CONF_DIR" ]; then
    CONF_DIR=/etc/ocserv
fi
if [ -z "$CONF_FILE" ]; then
    CONF_FILE=$CONF_DIR/ocserv.conf
fi
if [ ! -f "$CONF_FILE" ]; then
    err "$CONF_FILE not found, skipping."
    exit 2
fi

ca_key=$CONF_DIR/ca-key.pem
ca_cfg=$CONF_DIR/ca.cfg
import_v_or_die ca_cert ca-cert
import_v_or_die server_key server-key
server_cfg=$CONF_DIR/server.cfg
import_v_or_die server_cert server-cert
import_v_or_die auth auth

if [ ! -f "$ca_cert" ]; then
    if [ ! -f "$ca_key" ]; then
        log_fgen "$ca_key"
        certtool --generate-privkey --outfile $ca_key
    fi
    if [ ! -f "$ca_cfg" ]; then
        log_fgen "$ca_cfg"
        cat << EOF > $ca_cfg
cn = "example.com"
organization = "example.com"
serial = 1
expiration_days = -1
ca
signing_key
cert_signing_key
crl_signing_key
EOF
    fi
    log_fgen "$ca_cert"
    certtool --generate-self-signed --load-privkey $ca_key --template $ca_cfg --outfile $ca_cert
fi
if [ ! -f "$server_cert" ]; then
    if [ ! -f "$server_key" ]; then
        log_fgen "$server_key"
        certtool --generate-privkey --outfile $server_key
    fi
    if [ ! -f "$server_cfg" ]; then
        log_fgen "$server_cfg"
        cat << EOL > $server_cfg
cn = "example.com"
organization = "example.com"
expiration_days = -1
signing_key
encryption_key
tls_www_server
EOL
    fi
    log_fgen "$server_cert"
    certtool --generate-certificate --load-privkey $server_key --load-ca-certificate $ca_cert --load-ca-privkey $ca_key --template $server_cfg --outfile $server_cert
fi

# generate default user, password and otp secret
auth_plain=${auth##*[}
auth_plain=${auth_plain%%]*}
passwd=$(echo $auth_plain | sed -n -e 's@.*passwd\s*=\s*\(.*\)@\1@p')
passwd=${passwd%%,*}
if [ -n "$USERNAME" ]; then
    new_username="$USERNAME"
else
    new_username=admin
fi
if [ ! -z "$passwd" ]; then
    if [ ! -f "$passwd" ]; then
        log_fgen "$passwd"
        if [ -n "$PASSWORD" ]; then
            new_password="$PASSWORD"
        else
            new_password=
        fi
        new_group=ALL
        if [ -n "$new_password" ]; then
            echo "$new_password" | ocpasswd -c $passwd -g $new_group $new_username
        else
            echo "$new_username:$new_group:\$1\$XDzWOy/Q\$v21pfunB39GWdMhT//5Ex/" >> $passwd
        fi
        log "new user added (username = $new_username, password = $new_password, group = $new_group)"
    fi
fi
otp=$(echo $auth_plain | sed -n -e 's@.*otp\s*=\s*\(.*\)@\1@p')
otp=${otp%%,*}
if [ ! -z "$otp" ]; then
    if [ ! -f "$otp" ]; then
        log_fgen "$otp"
        if [ -n "$OTP_PIN" ]; then
            otp_pin="$OTP_PIN"
        else
            otp_pin=-
        fi
        hex_secret=$(xxd -l 20 -p /dev/urandom)
        base32_secret=$(echo $hex_secret | xxd -r -p | base32)
        new_issuer=ocserv
        echo "HOTP/T30 $new_username $otp_pin $hex_secret" > $otp
        log "the otp secret of $new_username added (hex secret = $hex_secret, base32 secret = $base32_secret, opt pin = $otp_pin)"
        uri="otpauth://totp/$new_issuer:$new_username?secret=${base32_secret}&digits=6&issuer=$new_issuer&period=30"
        log "$uri"
        qrencode -t ANSIUTF8 "$uri"
    fi
fi

# Enable ipv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Enable NAT forwarding
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# Enable TAP/TUN: https://www.kernel.org/doc/Documentation/admin-guide/devices.txt
if [ ! -c "/dev/net/tun" ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 -m 600
fi

exec "$@"
