FROM docker.io/alpine:3.19

ENV OC_VERSION=1.2.4
# ENV OC_GPG_KEY=96865171
# gpg --keyserver pgp.mit.edu --receive-keys 96865171
# gpg: keybox '/root/.gnupg/pubring.kbx' created

# gpg: /root/.gnupg/trustdb.gpg: trustdb created
# gpg: key 90BD336396865171: public key "Nikos Mavrogiannopoulos <nmav@gnutls.org>" imported
# gpg: key 29EE58B996865171: 1 duplicate signature removed
# gpg: key 29EE58B996865171: 1 signature reordered
# gpg: key 29EE58B996865171: public key "Nikos Mavrogiannopoulos <n.mavrogiannopoulos@gmail.com>" imported
# gpg: Total number processed: 2
# gpg:               imported: 2
ENV OC_GPG_KEY=90BD336396865171

RUN set -ex; \
    apk add --no-cache --virtual .build-dependencies \
		wget \
		gpgme \
		gcc \
		make \
		autoconf \
		xz \
		linux-headers \
		readline-dev \
		libnl3-dev \
		musl-dev \
		gnutls-dev \
		linux-pam-dev \
		libseccomp-dev \
		lz4-dev \
		libev-dev \
		oath-toolkit-dev; \
	wget https://www.infradead.org/ocserv/download/ocserv-${OC_VERSION}.tar.xz -O ocserv.tar.xz; \
	wget https://www.infradead.org/ocserv/download/ocserv-${OC_VERSION}.tar.xz.sig -O ocserv.tar.xz.sig; \
	wget https://ocserv.openconnect-vpn.net/96865171.asc -O key.asc; \
	gpg --import key.asc; \
	# gpg --keyserver pgp.mit.edu --receive-keys ${OC_GPG_KEY}; \
	gpg --verify ocserv.tar.xz.sig ocserv.tar.xz; \
	tar -xf ocserv.tar.xz; \
	rm ocserv.tar.xz*; \
	cd ocserv-${OC_VERSION}; \
	./configure; \
	make; \
	make install; \
	cd ..; \
	rm -fr ocserv-${OC_VERSION}; \
	run_dependencies="$( \
		scanelf --needed --nobanner /usr/local/sbin/ocserv \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| xargs -r apk info --installed \
			| sort -u \
		)"; \
	apk add --no-cache --virtual .run-dependencies \
		${run_dependencies} \
		gnutls-utils \
		iptables \
		libnl3 \
		readline \
		libseccomp \
		lz4-libs \
		oath-toolkit-oathtool \
		libqrencode-tools \
		coreutils; \
	apk del .build-dependencies; \
	rm -fr /var/cache/apk/*;

COPY src /etc/ocserv
COPY entrypoint.sh /entrypoint.sh

WORKDIR /etc/ocserv
ENTRYPOINT ["/entrypoint.sh"]
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
