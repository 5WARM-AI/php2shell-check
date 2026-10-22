#!/bin/sh
# Builds stand-in PHP binaries at the install paths check.sh searches. Runs inside a throwaway container only.
set -e
stub() { mkdir -p "$(dirname "$1")"; printf '#!/bin/sh\necho "%s"\n' "$2" > "$1"; chmod +x "$1"; }
stub /usr/bin/php8.1                          "PHP 8.1.30 (cli) (built: Jun  1 2026)"
stub /usr/sbin/php-fpm8.3                     "PHP 8.3.35 (fpm-fcgi) (built: Oct  1 2026)"
stub /opt/remi/php83/root/usr/bin/php         "PHP 8.3.36 (cli) (built: Oct 21 2026)"
stub /opt/remi/php83/root/usr/sbin/php-fpm    "PHP 8.3.35 (fpm-fcgi) (built: Oct  1 2026)"
stub /opt/remi/php83/root/usr/bin/php-cgi     "PHP 8.3.35 (cgi-fcgi) (built: Oct  1 2026)"
stub /opt/cpanel/ea-php82/root/usr/bin/php    "PHP 8.2.34 (cli) (built: Sep  1 2026)"
stub /opt/cpanel/ea-php82/root/usr/sbin/php-fpm "PHP 8.2.35 (fpm-fcgi) (built: Oct 21 2026)"
stub /opt/plesk/php/8.4/bin/php               "PHP 8.4.27 (cli) (built: Oct 21 2026)"
stub /opt/alt/php74/usr/bin/php               "PHP 7.4.33 (cli) (built: Nov  1 2022)"
stub /usr/local/lsws/lsphp83/bin/lsphp        "PHP 8.3.35 (litespeed) (built: Oct  1 2026)"
stub /usr/local/bin/frankenphp                "FrankenPHP v1.9.0 PHP 8.5.12 Caddy v2.10.0"
mkdir -p /usr/lib/apache2/modules
printf 'junk\0X-Powered-By: PHP/8.1.33\0junk' > /usr/lib/apache2/modules/libphp8.1.so
stub /usr/sbin/apachectl " php_module (shared)"
