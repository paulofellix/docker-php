FROM php:7.1-apache

# install requirements for laravel/lumen
RUN apt-get update && apt-get install -y curl git unzip libaio1 unixodbc-dev libmcrypt-dev libxml2-dev apt-transport-https zlib1g-dev
RUN docker-php-ext-install mbstring mcrypt xml zip

# install Microsoft ODBC Driver 13.1 for SQL Server
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install msodbcsql \
    # # optional: for bcp and sqlcmd
    # && ACCEPT_EULA=Y apt-get install mssql-tools \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

# install driver sqlsrv
RUN pecl install sqlsrv pdo_sqlsrv \
    && docker-php-ext-enable sqlsrv pdo_sqlsrv

# copy oci8 driver
COPY instantclient_12_2.zip /opt/

# install oci8 driver
RUN unzip /opt/instantclient_12_2.zip -d /opt/ && rm -f /opt/instantclient_12_2.zip \
    && ln -sf /opt/instantclient_12_2/sqlplus /usr/local/bin/ \
    && ln -sf /opt/instantclient_12_2/libclntsh.so.12.1 /opt/instantclient_12_2/libclntsh.so \
    && docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/instantclient_12_2/ \
    && docker-php-ext-install oci8

# install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('SHA384', 'composer-setup.php') === '669656bab3166a7aff8a7506b8cb2d1c292f042046c5a994c43155c0be6190fa0355160742ab2e1c88d40d5be660b410') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/local/bin/composer

# install locales
RUN apt-get install -y locales && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen \
    && service apache2 restart \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
