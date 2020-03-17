#!/bin/sh
# File format must be LF, not CRLF

php-fpm
nginx -g "daemon off;"
