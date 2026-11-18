FROM php:8.2-apache-bookworm AS Builder
WORKDIR /var/www/html
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        git \
        libpq-dev \
        libzip-dev \
        zip \
        unzip \
    && docker-php-ext-install pdo_pgsql bcmath zip \
    && pecl channel-update pecl.php.net \
    && pecl install redis-6.1.0 \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
COPY . .
RUN mkdir -p bootstrap/cache storage/framework/cache \
    storage/framework/sessions storage/framework/views \
    storage/logs \
    && chmod -R 775 bootstrap/cache storage
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

FROM php:8.2-apache-bookworm
WORKDIR /var/www/html
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        libzip4 \
        libpq-dev \
        libzip-dev \
    && docker-php-ext-install pdo_pgsql bcmath zip \
    && pecl channel-update pecl.php.net \
    && pecl install redis-6.1.0 \
    && docker-php-ext-enable redis \
    && a2enmod rewrite \
    && apt-get purge -y --auto-remove libpq-dev libzip-dev \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /var/www/html /var/www/html
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri 's|^[[:space:]]*DocumentRoot.*|        DocumentRoot /var/www/html/public|' \
    /etc/apache2/sites-available/000-default.conf
RUN echo '<Directory /var/www/html/public>' >> /etc/apache2/apache2.conf \
    && echo '    AllowOverride All' >> /etc/apache2/apache2.conf \
    && echo '    Require all granted' >> /etc/apache2/apache2.conf \
    && echo '</Directory>' >> /etc/apache2/apache2.conf
EXPOSE 80
CMD ["apache2-foreground"]