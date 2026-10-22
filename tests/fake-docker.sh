#!/bin/sh
# Stand-in "docker" command with canned answers, so container detection is tested without a Docker daemon.
case "$1" in
  ps) printf 'c1\nc2\nc3\n' ;;
  inspect) case "$4" in c1) echo "/shop-web (php:8.3.35-fpm)";; c2) echo "/blog (ubuntu:24.04)";; c3) echo "/cache (redis:7-alpine)";; esac ;;
  exec) case "$2" in
          c1) echo "PHP 8.3.35 (cli) (built: Oct  1 2026)" ;;
          c2) echo "PHP 8.3.6 (cli) (built: Oct 20 2026)"; echo "@@deb php8.3-cli 8.3.6-0ubuntu0.24.04.13" ;;
          c3) : ;;
        esac ;;
esac
