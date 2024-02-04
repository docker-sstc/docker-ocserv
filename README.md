# docker-ocserv

Dockerize OpenConnect VPN Server with 2fa (OTP) enabled

## Usage

```bash
# Default username = admin, password = "" (empty)
docker run -d \
    --name ocserv \
    --privileged \
    -p 443:443 \
    -p 443:443/udp \
    sstc/ocserv

# To see otp secret & qrcode
docker logs -f ocserv
```

```bash
# Customize username, password and verbose details
docker run -d \
    --name ocserv \
    --privileged \
    -p 443:443 \
    -p 443:443/udp \
    -e USERNAME=sstc \
    -e PASSWORD=123456 \
    -e VERBOSE=true \
    sstc/ocserv
```

## Advanced usage

Add more users

```bash
# Get into container
docker exec -it ocserv /bin/sh

# Add new user
new_username="<username>"
ocpasswd $new_username

# Add otp for the new user
otp=/etc/ocserv/otp
otp_pin=0000
hex_secret=$(xxd -l 20 -p /dev/urandom)
base32_secret=$(echo $hex_secret | xxd -r -p | base32)
new_issuer=ocserv
echo "HOTP/T30 $new_username $otp_pin $hex_secret" > $otp
echo "the otp secret of $new_username added (hex secret = $hex_secret, base32 secret = $base32_secret)"
uri="otpauth://totp/$new_issuer:$new_username?secret=${base32_secret}&digits=6&issuer=$new_issuer&period=30"
echo "$uri"
qrencode -t ANSIUTF8 "$uri"

# Show current and future 5 otps
oathtool --totp --verbose -w 5 $hex_secret
```

If you want to setup everything manually, you can generate all the necessary files and mount them, e.q.

```bash
docker run -d \
    --privileged \
    --name ocserv \
    -p 443:443 \
    -p 443:443/udp \
    -v /my/custom/config:/tmp/ocserv \
    -e CONF_FILE=/tmp/ocserv/ocserv.conf \
    sstc/ocserv ocserv -c /tmp/ocserv/ocserv.conf -f
```

## Dev memo

```bash
docker build --no-cache -t ocserv .
docker run --rm --name ocserv --privileged ocserv

docker build -t ocserv .
docker run --rm -it -v ./entrypoint.sh:/entrypoint.sh -v ./src:/etc/ocserv --entrypoint /bin/sh ocserv

docker exec ocserv oathtool --verbose --totp -w 5 "<hex secret>"
```

## Refs

- `https://github.com/TommyLau/docker-ocserv`
- `https://github.com/iw4p/OpenConnect-Cisco-AnyConnect-VPN-Server-OneKey-ocserv`
