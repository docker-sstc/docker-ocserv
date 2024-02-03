# docker-ocserv

This image is based on `https://github.com/TommyLau/docker-ocserv`

## Usage

```bash
docker run -d \
    --name ocserv \
    --privileged \
    -p 443:443 \
    -p 443:443/udp \
    sstc/ocserv
```

```bash
docker run -d \
    --name ocserv \
    --privileged \
    -p 443:443 \
    -p 443:443/udp \
    -e USERNAME=sstc \
    -e PASSWORD=123456 \
    sstc/ocserv
```

```bash
# delete default user
docker exec ocserv ocpasswd -d admin
```

```bash
# add new user
docker exec -it ocserv /bin/sh

new_username="<username>"
ocpasswd $new_username

# add otp for the new user
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

# show current and future 5 otps
oathtool --totp --verbose -w 5 $hex_secret
```

```bash
# if you want to manually setup everything, you can generate all the necessary files and mount them
docker run -d \
    --name ocserv \
    --privileged \
    -p 443:443 \
    -p 443:443/udp \
    -v /my/custom/config:/tmp/ocserv \
    -e CONF_DIR=/tmp/ocserv \
    sstc/ocserv ocserv -c /tmp/ocserv/ocserv.conf -f
```

## Dev memo

```bash
docker build --no-cache -t ocserv .
docker run --rm --name ocserv --privileged ocserv

docker build -t ocserv .
docker run --rm -it -v ./entrypoint.sh:/entrypoint.sh -v ./src:/etc/ocserv --entrypoint /bin/sh ocserv
```
