FROM php:7.0.10-fpm

MAINTAINER Eric Owens <eowens@meteoreducation.com>
RUN apt-get update

# install the PHP extensions we need
RUN apt-get update --fix-missing && apt-get install -y locales unixodbc libgss3 odbcinst devscripts debhelper dh-exec dh-autoreconf libreadline-dev libltdl-dev unixodbc-dev wget unzip \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

RUN apt-get update && apt-get install -y \
  libxrender1 \
  libfontconfig1 \
  libx11-dev \
  libjpeg62 \
  libxtst6

RUN apt-get update && apt-get install -y \
  mysql-client \
  libmcrypt-dev \
  libfreetype6-dev \
  libjpeg62-turbo-dev \
  libpng12-dev \
  libldap2-dev

# https://bugs.php.net/bug.php?id=49876
RUN ln -fs /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/

RUN echo "Installing PHP extensions" \
  && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
  && docker-php-ext-install -j$(nproc) ldap mcrypt pdo_mysql gd \
  && docker-php-ext-enable ldap mcrypt pdo_mysql



RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/xdebug.ini

# Compile odbc_config
RUN cd /usr/local/src/ && dget -ux http://http.debian.net/debian/pool/main/u/unixodbc/unixodbc_2.3.1-3.dsc \
    && cd unixodbc-2.3.1/ && apt-get update && dpkg-buildpackage -uc -d -us -B && cp ./exe/odbc_config /usr/local/bin/

## Microsoft ODBC Driver 13 for Linux
RUN cd /usr/local/src/ \
    && wget "https://meetsstorenew.blob.core.windows.net/contianerhd/Ubuntu%2013.0%20Tar/msodbcsql-13.0.0.0.tar.gz?st=2016-10-18T17%3A29%3A00Z&se=2022-10-19T17%3A29%3A00Z&sp=rl&sv=2015-04-05&sr=b&sig=cDwPfrouVeIQf0vi%2BnKt%2BzX8Z8caIYvRCmicDL5oknY%3D" -O msodbcsql-13.0.0.0.tar.gz \
    && tar xf msodbcsql-13.0.0.0.tar.gz && cd msodbcsql-13.0.0.0/ \
    && ldd lib64/libmsodbcsql-13.0.so.0.0; echo "RET=$?" \
    && sed -i 's/$(uname -p)/"x86_64"/g' ./install.sh \
    && ./install.sh install --force --accept-license

# Install PHP extensions for SQL Server
RUN cd /tmp && wget https://github.com/Microsoft/msphpsql/releases/download/v4.0.5-Linux/Ubuntu15.zip \
    && unzip Ubuntu15.zip \
    && mv -v Ubuntu15/* /usr/local/lib/php/extensions/no-debug-non-zts-20151012/ \
    && rm /usr/local/lib/php/extensions/no-debug-non-zts-20151012/signature \
    && rm -rf /tmp/*

RUN echo "extension=php_sqlsrv_7_nts.so" >> /usr/local/etc/php/conf.d/sqlsvr.ini \
    && echo "extension=php_pdo_sqlsrv_7_nts.so" >> /usr/local/etc/php/conf.d/sqlsvr.ini \
    && locale-gen

CMD ["php-fpm", "-F"]

EXPOSE 9000


WORKDIR /var/www
