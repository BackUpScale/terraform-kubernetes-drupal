# https://hub.docker.com/r/webdevops/php/tags
FROM webdevops/php-nginx:8.4

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y tzdata mariadb-client

# Set the time zone.
ENV TZ=America/Toronto
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
  dpkg-reconfigure --frontend noninteractive tzdata

WORKDIR /app

# Copy Composer files.
COPY drupal/composer.* ./

# Run composer install to install the dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

# Run Drush from anywhere.
ENV PATH="/app/vendor/bin:${PATH}"

COPY drupal/config config/
COPY drupal/web/modules/custom web/modules/custom/
COPY drupal/web/sites/default/settings.php web/sites/default/settings.php
COPY drupal/web/sites/default/settings.kubernetes.php web/sites/default/settings.local.php
RUN chmod 444 web/sites/default/settings.*

ENV WEB_DOCUMENT_ROOT=/app/web

# Clean up.
RUN apt-get remove -y   && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* \
