# Digest-pinned so every build uses the identical base even when the rolling
# 8.4 tag is republished. To bump: take `digest` from
# https://hub.docker.com/v2/repositories/webdevops/php-nginx/tags/8.4 and
# confirm the PHP version actually changed with
# `docker run --rm webdevops/php-nginx:8.4 php --version`; Hub timestamps and
# digest churn alone do not indicate a new PHP release.
FROM webdevops/php-nginx:8.4@sha256:9d23e38bb909caf91653d3c77bf611fdf1fe9d4da2e19404acf624f9ae38b640

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

# Restrict PHP execution to Drupal's entry points, deny sensitive paths, and
# rate-limit the unauthenticated mail-sending endpoints.
COPY nginx/ /opt/docker/etc/nginx/

ENV WEB_DOCUMENT_ROOT=/app/web

# Clean up.
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*
