FROM centos:centos8

WORKDIR /app

RUN  dnf -y update \
  && dnf -y install epel-release \
  && dnf -y install nginx \
  && dnf -y install unzip \
  && dnf -y localinstall http://rpms.famillecollet.com/enterprise/remi-release-8.rpm \
  && dnf -y module enable php:remi-7.4 \
  && dnf -y install php php-mysql php-mbstring php-fpm php-zip php-dom \
  && dnf clean all \
  && systemctl enable php-fpm

RUN cd '/' \
  && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php -r "if (hash_file('SHA384', 'composer-setup.php') !== trim(file_get_contents('https://composer.github.io/installer.sig'))) { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
  && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
  && rm composer-setup.php

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /composer
ENV PATH $PATH:/composer/vendor/bin

RUN mkdir /var/run/php-fpm
ADD confFiles/nginx/nginx.conf /etc/nginx/nginx.conf
ADD confFiles/nginx/webapp.conf /etc/nginx/conf.d/webapp.conf
ADD confFiles/php/php.ini /etc/php/php.ini
ADD confFiles/php/www.conf /etc/php-fpm.d/www.conf
ADD debugFiles/phpinfo.php /var/www/html/phpinfo.php

ADD application /app
RUN chown -R nginx /app/storage
RUN chmod -R 755 /app/storage
RUN chown -R nginx /app/bootstrap/cache
RUN chmod -R 755 /app/bootstrap/cache

RUN composer global require "laravel/installer"

EXPOSE 80

ADD startScript.sh /root/startScript.sh
RUN chmod +x /root/startScript.sh
CMD ["/root/startScript.sh"]
