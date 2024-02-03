#!/bin/sh

if [ -z "$CONF_DIR" ]; then
    CONF_DIR=/etc/ocserv
fi
if [ -z "$CONF_FILE" ]; then
    CONF_FILE=$CONF_DIR/ocserv.conf
fi

if [ ! -f "$CONF_FILE" ]; then
    >&2 echo "$CONF_FILE" not found, skipping.
    exit 2
fi

function import_v_or_die() {
    local v=$(sed $CONF_FILE -n -e "s@^\s*${2}\s*=\s*\(.*\)@\1@p")
    if [ -z "$v" ]; then
        >&2 echo "$2" not found in $CONF_FILE, skipping.
        exit 2
    fi
    eval "$1=$v"
}

ca_key=$CONF_DIR/ca-key.pem
ca_cfg=$CONF_DIR/ca.cfg
import_v_or_die ca_cert ca-cert
import_v_or_die server_key server-key
server_cfg=$CONF_DIR/server.cfg
import_v_or_die server_cert server-cert
import_v_or_die auth auth

if [ ! -f "$ca_cert" ]; then
    if [ ! -f "$ca_key" ]; then
        certtool --generate-privkey --outfile $ca_key
    fi
    if [ ! -f "$ca_cfg" ]; then
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
    certtool --generate-self-signed --load-privkey $ca_key --template $ca_cfg --outfile $ca_cert
fi
if [ ! -f "$server_cert" ]; then
    if [ ! -f "$server_key" ]; then
        certtool --generate-privkey --outfile $server_key
    fi
    if [ ! -f "$server_cfg" ]; then
        cat << EOL > $server_cfg
cn = "example.com"
organization = "example.com"
expiration_days = -1
signing_key
encryption_key
tls_www_server
EOL
    fi
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
if [ ! -f "$passwd" ]; then
    if [ -n "$PASSWORD" ]; then
        new_password="$PASSWORD"
    else
        new_password=
    fi
    new_group=ALL
    echo "$passwd file not found, auto generating..."
    if [ -n "$new_password" ]; then
        echo "$new_password" | ocpasswd -c $passwd -g $new_group $new_username
    else
        echo "$new_username:$new_group:\$1\$XDzWOy/Q\$v21pfunB39GWdMhT//5Ex/" >> $passwd
    fi
    echo "new user added (username = $new_username, password = $new_password)"
fi
otp=$(echo $auth_plain | sed -n -e 's@.*otp\s*=\s*\(.*\)@\1@p')
otp=${otp%%,*}
if [ ! -z "$otp" ]; then
    if [ ! -f "$otp" ]; then
        echo "$otp file not found, auto generating..."
        if [ -n "$OTP_PIN" ]; then
            otp_pin="$OTP_PIN"
        else
            otp_pin=-
        fi
        hex_secret=$(xxd -l 20 -p /dev/urandom)
        base32_secret=$(echo $hex_secret | xxd -r -p | base32)
        new_issuer=ocserv
        echo "HOTP/T30 $new_username $otp_pin $hex_secret" > $otp
        echo "the otp secret of $new_username added (hex secret = $hex_secret, base32 secret = $base32_secret, opt pin = $otp_pin)"
        uri="otpauth://totp/$new_issuer:$new_username?secret=${base32_secret}&digits=6&issuer=$new_issuer&period=30"
        echo "$uri"
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
