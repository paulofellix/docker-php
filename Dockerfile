FROM php:7.1-apache

# install requirements for laravel/lumen
RUN apt-get update && apt-get install -y curl git unzip libaio1 unixodbc-dev libmcrypt-dev libxml2-dev apt-transport-https zlib1g-dev
RUN docker-php-ext-install mbstring mcrypt xml zip pdo mysqli pdo_mysql soap

# install Microsoft ODBC Driver 13.1 for SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install msodbcsql \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

# install driver sqlsrv
RUN pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv

# copy oci8 and pdo_oci driver
COPY instantclient_12_2.zip /tmp/

# install oci8 driver
RUN mkdir -p /opt/oracle \
    && unzip /tmp/instantclient_12_2.zip -d /opt/oracle/ && rm -f /tmp/instantclient_12_2.zip \
    && mv /opt/oracle/instantclient_12_2 /opt/oracle/instantclient \
    && ln -sf /opt/oracle/instantclient /sqlplus /usr/local/bin/ \
    && ln -sf /opt/oracle/instantclient/libclntsh.so.12.1 /opt/oracle/instantclient/libclntsh.so \
    && ORACLE_HOME=/opt/oracle/instantclient/ \
    && docker-php-ext-configure oci8 --with-oci8=shared,instantclient,/opt/oracle/instantclient/ \
    && docker-php-ext-install oci8 \
    && docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/opt/oracle/instantclient,12.1 \
    && docker-php-ext-install pdo_oci

# install composer
RUN /usr/bin/curl -sS https://getcomposer.org/installer | php
RUN /bin/mv composer.phar /usr/local/bin/composer
RUN /usr/local/bin/composer create-project laravel/lumen /var/www/app --prefer-dist
RUN /bin/chown www-data:www-data -R /var/www/app/storage


# Configure apache to laravel/lumen
COPY 000-laravel.conf /etc/apache2/sites-available/
RUN a2dissite 000-default && a2enmod rewrite &&a2ensite 000-laravel

# install locales
RUN apt-get install -y locales && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && service apache2 restart \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
