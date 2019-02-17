FROM centos:7.6.1810
MAINTAINER Juan Manuel Carrillo Moreno <inetshell@gmail.com>
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.license=GPL-3.0 \
    org.label-schema.name=samba-dc \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url=https://github.com/inetshell/samba-dc

ENV ADMIN_PASSWORD_SECRET=samba-admin-password \
    ALLOW_DNS_UPDATES=secure \
    BIND_INTERFACES_ONLY=yes \
    DOMAIN_ACTION=provision \
    DOMAIN_LOGONS=yes \
    DOMAIN_MASTER=no \
    INTERFACES="lo eth0" \
    LOG_LEVEL=1 \
    MODEL=standard \
    REALM=ad.example.com \
    SERVER_STRING="Samba Domain Controller" \
    WINBIND_USE_DEFAULT_DOMAIN=yes \
    WORKGROUP=WORKGROUP

ARG BIND9_VER=9.13.2
ARG BIND9_SHA=6c044e9ea81add9dbbd2f5dfc224964cc6b6e364e43a8d6d8b574d9282651802
ARG SAMBA_VERSION=4.9.4

RUN \
  # Install system updates
  yum update -y && \
  # Install Samba dependencies
  yum install -y epel-release && \
  yum install -y attr bind-utils docbook-style-xsl gcc gdb krb5-workstation \
       libsemanage-python libxslt perl perl-ExtUtils-MakeMaker \
       perl-Parse-Yapp perl-Test-Base pkgconfig policycoreutils-python \
       python2-crypto gnutls-devel libattr-devel keyutils-libs-devel \
       libacl-devel libaio-devel libblkid-devel libxml2-devel openldap-devel \
       pam-devel popt-devel python-devel readline-devel zlib-devel systemd-devel \
       lmdb-devel jansson-devel gpgme-devel pygpgme libarchive-devel lmdb-devel && \
  cd /tmp && \

  # Build Samba
  curl -O https://download.samba.org/pub/samba/stable/samba-${SAMBA_VERSION}.tar.gz && \
  tar xvzf samba-${SAMBA_VERSION}.tar.gz && \
  cd /tmp/samba-${SAMBA_VERSION}/ && \
  ./configure \
    --enable-fhs \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --with-piddir=/run/samba \
    --with-pammodulesdir=/lib/security \
    --with-logfilebase=/var/log/samba \
    --libdir=/usr/lib64 \
    --with-modulesdir=/usr/lib64/samba \
    --with-lockdir=/var/run/samba \
    --with-statedir=/var/lib/samba \
    --with-cachedir=/var/cache/samba \
    --with-piddir=/var/run/samba \
    --with-smbpasswd-file=/var/lib/samba/private/smbpasswd \
    --with-privatedir=/var/lib/samba/private \
    --with-bind-dns-dir=/var/lib/samba/bind-dns \
    --enable-gnutls && \
  make && \
  make install && \

  #Install BIND dependencies
  yum install -y krb5-devel openssl-devel libcap-devel && \
  cd /tmp && \
  curl -O ftp://ftp.isc.org/isc/bind9/$BIND9_VER/bind-$BIND9_VER.tar.gz && \
  tar xvzf bind-$BIND9_VER.tar.gz && \
  echo "$BIND9_SHA  bind-$BIND9_VER.tar.gz" > checksums && \
  sha256sum -c checksums && \
  cd /tmp/bind-$BIND9_VER/ && \
  export CFLAGS=-O2 && \
  ./configure \
    --prefix=/usr \
    --exec-prefix=/usr \
    --libdir=/usr/lib64 \
    --with-gssapi=/usr/include/gssapi \
    --with-dlopen=yes \
    --sysconfdir=/etc/bind \
    --localstatedir=/var \
    --with-openssl=/usr \
    --enable-linux-caps \
    --with-libxml2 \
    --enable-threads \
    --enable-ipv6 \
    --enable-shared \
    --with-libtool && \
  make && \
  for TARGET in lib bin/delv bin/dig bin/dnssec bin/nsupdate; do \
    make -C $TARGET install; \
  done && \

  # Remove temp files
  yum remove -y *-devel* && \
  cd /tmp && \
  rm -rf /tmp/*

COPY *.conf.j2 /root/
COPY entrypoint.sh /usr/local/bin/

# Set permissions to entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

VOLUME /etc/samba /var/lib/samba
EXPOSE 53 53/udp 88 88/udp 135 137-138/udp 139 389 445 464 464/udp 636 3268-3269 49152-65535

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
