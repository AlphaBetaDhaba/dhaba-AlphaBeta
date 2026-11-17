FROM php:8.2-apache-bookworm AS Builder
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y --no-install-recommends \
    git\
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install pdo_pgsql bcmath zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock8 ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

FROM php:8.2-apache-bookworm
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libzip4 \
    && docker-php-ext-install pdo_pgsql bcmath zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /var/www/html /var/www/html
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/000-default.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/apache2.conf \
    && chown -R www-data:www-data storage bootstrap/cache
EXPOSE 80
CMD ["apache2-foreground"]