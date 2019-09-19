FROM alpine:3.10
MAINTAINER Adam Wallner <adam.wallner@gmail.com>

# The version numbers to download and build
ENV MARIADB_VER 10.4.8
ENV JUDY_VER 1.0.5

RUN \
    export CPU=`cat /proc/cpuinfo | grep -c processor` \
    # Add testing repo
    && echo http://nl.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
    # Install packages
    && apk add --no-cache \
    # Install utils
    pwgen openssl ca-certificates \
    # Installing needed libs
    libstdc++ libaio gnutls ncurses-libs libcurl libxml2 boost proj geos \
    # Install MariaDB build deps
    alpine-sdk cmake ncurses-dev gnutls-dev curl-dev libxml2-dev libaio-dev linux-headers bison boost-dev \
    # Update CA certs
    && update-ca-certificates \
    # Add group and user for mysql
    && addgroup -S -g 500 mysql \
    && adduser -S -D -H -u 500 -G mysql -g "MySQL" mysql \
    # Download and unpack mariadb
    && mkdir -p /opt/src \
    && mkdir -p /etc/mysql \
    && wget -O /opt/src/mdb.tar.gz https://downloads.mariadb.org/interstitial/mariadb-${MARIADB_VER}/source/mariadb-${MARIADB_VER}.tar.gz \
    && cd /opt/src && tar -xf mdb.tar.gz && rm mdb.tar.gz \
    # Download and unpack Judy (needed for OQGraph)
    && wget -O /opt/src/judy.tar.gz http://downloads.sourceforge.net/project/judy/judy/Judy-${JUDY_VER}/Judy-${JUDY_VER}.tar.gz \
    && cd /opt/src && tar -xf judy.tar.gz && rm judy.tar.gz \
    # Build Judy
    && cd /opt/src/judy-${JUDY_VER} \
    && CFLAGS="-O2 -s" CXXFLAGS="-O2 -s" ./configure \
    && make \
    && make install \
    # Build maridb
    && mkdir -p /tmp/_ \
    && cd /opt/src/mariadb-${MARIADB_VER} \
    && cmake . \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DCOMMON_C_FLAGS="-O3 -s -fno-omit-frame-pointer -pipe" \
    -DCOMMON_CXX_FLAGS="-O3 -s -fno-omit-frame-pointer -pipe" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DSYSCONFDIR=/etc/mysql \
    -DMYSQL_DATADIR=/var/lib/mysql \
    -DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
    -DDEFAULT_CHARSET=utf8 \
    -DDEFAULT_COLLATION=utf8_general_ci \
    -DENABLED_LOCAL_INFILE=ON \
    -DINSTALL_INFODIR=share/mysql/docs \
    -DINSTALL_MANDIR=/tmp/_/share/man \
    -DINSTALL_PLUGINDIR=lib/mysql/plugin \
    -DINSTALL_SCRIPTDIR=bin \
    -DINSTALL_DOCREADMEDIR=/tmp/_/share/mysql \
    -DINSTALL_SUPPORTFILESDIR=share/mysql \
    -DINSTALL_MYSQLSHAREDIR=share/mysql \
    -DINSTALL_DOCDIR=/tmp/_/share/mysql/docs \
    -DINSTALL_SHAREDIR=share/mysql \
    -DWITH_READLINE=ON \
    -DWITH_ZLIB=system \
    -DWITH_SSL=system \
    -DWITH_LIBWRAP=OFF \
    -DWITH_JEMALLOC=no \
    -DWITH_EXTRA_CHARSETS=complex \
    -DPLUGIN_ARCHIVE=STATIC \
    -DPLUGIN_BLACKHOLE=DYNAMIC \
    -DPLUGIN_INNOBASE=STATIC \
    -DPLUGIN_PARTITION=AUTO \
    -DPLUGIN_CONNECT=NO \
    -DPLUGIN_TOKUDB=NO \
    -DPLUGIN_FEEDBACK=NO \
    -DPLUGIN_OQGRAPH=YES \
    -DPLUGIN_FEDERATED=NO \
    -DPLUGIN_FEDERATEDX=NO \
    -DWITHOUT_FEDERATED_STORAGE_ENGINE=1 \
    -DWITHOUT_EXAMPLE_STORAGE_ENGINE=1 \
    -DWITHOUT_PBXT_STORAGE_ENGINE=1 \
    -DWITHOUT_ROCKSDB_STORAGE_ENGINE=1 \
    -DWITH_EMBEDDED_SERVER=OFF \
    -DWITH_UNIT_TESTS=OFF \
    -DENABLED_PROFILING=OFF \
    -DENABLE_DEBUG_SYNC=OFF \
    && make -j${CPU} \
    # Install
    && make -j${CPU} install \
    # Clean everything
    && rm -rf /opt/src \
    && rm -rf /tmp/_ \
    && rm -rf /usr/sql-bench \
    && rm -rf /usr/mysql-test \
    && rm -rf /usr/data \
    && rm -rf /usr/lib/python2.7 \
    && rm -rf /usr/bin/mysql_client_test \
    && rm -rf /usr/bin/mysqltest \
    # Remove packages
    && apk del \
    ca-certificates \
    # Remove no more necessary build dependencies
    alpine-sdk cmake ncurses-dev gnutls-dev curl-dev libxml2-dev libaio-dev linux-headers bison boost-dev \
    # Create needed directories
    && mkdir -p /var/lib/mysql \
    && mkdir -p /run/mysqld \
    && mkdir /etc/mysql/conf.d \
    && mkdir -p /opt/mariadb/pre-init.d \
    && mkdir -p /opt/mariadb/post-init.d \
    && mkdir -p /opt/mariadb/pre-exec.d \
    # Set permissions
    && chown -R mysql:mysql /var/lib/mysql \
    && chown -R mysql:mysql /run/mysqld \
    && chmod -R 755 /opt/mariadb \
    # Patching mysql_install_db: we don't have PAM plugin
    && sed -i 's/^.*auth_pam_tool_dir.*$/#auth_pam_tool_dir not exists/' /usr/bin/mysql_install_db

# Copy config into the image
ADD my.cnf /etc/mysql/my.cnf

# Default port
EXPOSE 3306

# The data volume
VOLUME ["/var/lib/mysql"]

# The entrypoint
ADD start.sh /opt/mariadb/start.sh
ENTRYPOINT ["/opt/mariadb/start.sh"]
