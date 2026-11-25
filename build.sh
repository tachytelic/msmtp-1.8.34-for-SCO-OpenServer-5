#!/bin/sh
# Build msmtp 1.8.34 natively on SCO OpenServer 5.0.7.
#
# Needs, on the build machine:
#   GCC 3.4.6 as /usr/local/bin/gcc-3.4.6 (its libiberty.a supplies getopt_long)
#   bash, GNU make (gmake) and GNU patch
#   static OpenSSL 3.5.0 at /usr/local/openssl-3.5.0
#   msmtp-1.8.34 unpacked next to this script (the .tar.xz from marlam.de)
#
# OpenSSL 3.x is used, not 1.0.2, because msmtp is GPLv3 and only the
# Apache-licensed OpenSSL 3 may be distributed linked to it.
#
# Output: msmtp-1.8.34/src/msmtp
set -e
SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=1.8.34
SRCDIR=msmtp-${VERSION}
OPENSSL="${OPENSSL:-/usr/local/openssl-3.5.0}"
CC="${GCC:-/usr/local/bin/gcc-3.4.6}"; export CC
PATH=/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin:/usr/local/bin; export PATH

cd "$SCRIPT_DIR/$SRCDIR"
if [ ! -f .sco_patched ]; then
    echo "Applying SCO patch..."
    patch -p1 < "$SCRIPT_DIR/patches/msmtp-${VERSION}-sco.patch"
    touch .sco_patched
fi

echo "Configuring..."
# PKG_CONFIG=/bin/true: there is no pkg-config; the libssl flags are given here.
# No GNU SASL, libidn or libsecret on this platform. msmtp has its own PLAIN,
# LOGIN and CRAM-MD5, which is what mail relays ask for.
CONFIG_SHELL=/usr/bin/bash /usr/bin/bash ./configure \
    --prefix=/usr/local --sysconfdir=/usr/local/etc \
    --with-tls=openssl --without-libgsasl --without-libidn --without-libsecret \
    --without-msmtpd --disable-nls \
    PKG_CONFIG=/bin/true \
    libssl_CFLAGS="-I$OPENSSL/include" \
    libssl_LIBS="$OPENSSL/lib/libssl.a $OPENSSL/lib/libcrypto.a" \
    CC="$CC" CFLAGS="-O2 -std=gnu99" LIBS="-liberty -lsocket"

echo "Compiling..."
gmake
strip src/msmtp
ls -l src/msmtp
