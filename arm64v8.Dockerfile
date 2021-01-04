FROM php:7.2-fpm-alpine

MAINTAINER IascCHEN

# 更新Alpine的软件源为国内（清华大学）的站点 TUNA
RUN echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.12/main" > /etc/apk/repositories && \
    echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.12/community" >> /etc/apk/repositories && \
    echo "https://mirror.tuna.tsinghua.edu.cn/alpine/edge/testing" >> /etc/apk/repositories

ARG LEAN_VERSION=2.1.4

WORKDIR /var/www/html

# Install dependencies
RUN apk update && apk add --no-cache \
    mysql-client \
    freetype libpng libjpeg-turbo freetype-dev libpng-dev libjpeg-turbo-dev \
    icu-libs \
    jpegoptim optipng pngquant gifsicle \
    supervisor \
    apache2 apache2-ctl apache2-proxy \
    curl git nodejs npm

# Installing extensions
RUN docker-php-ext-install mysqli pdo_mysql mbstring exif pcntl pdo bcmath zip
RUN docker-php-ext-configure gd --with-gd --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/
RUN docker-php-ext-install gd

#RUN curl -LJO https://github.com/Leantime/leantime/releases/download/v${LEAN_VERSION}/Leantime-v${LEAN_VERSION}.tar.gz && \
#    tar -zxvf Leantime-v${LEAN_VERSION}.tar.gz --strip-components 1 && \
#    rm Leantime-v${LEAN_VERSION}.tar.gz

RUN curl -sS https://install.phpcomposer.com/installer | php -- --install-dir=/usr/bin --filename=composer
RUN git clone https://github.com/iascchen/leantime.git .

RUN composer config -g repo.packagist composer https://packagist.phpcomposer.com
RUN composer install

RUN npm install
RUN ./node_modules/grunt/bin/grunt Build-All

RUN chown www-data -R .

COPY ./start.sh /start.sh
RUN chmod +x /start.sh

COPY config/custom.ini /usr/local/etc/php/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/app.conf  /etc/apache2/conf.d/app.conf

RUN sed -i '/LoadModule rewrite_module/s/^#//g' /etc/apache2/httpd.conf && \
    sed -i 's#AllowOverride [Nn]one#AllowOverride All#' /etc/apache2/httpd.conf && \
    sed -i '$iLoadModule proxy_module modules/mod_proxy.so' /etc/apache2/httpd.conf

# Expose port 9000 and start php-fpm server
ENTRYPOINT ["/start.sh"]
EXPOSE 80
