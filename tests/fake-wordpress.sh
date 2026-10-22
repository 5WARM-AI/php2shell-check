#!/bin/sh
# Builds a synthetic WordPress site and a stand-in "wp" command. Plugin headers only; no backdoor code.
set -e
S=/srv/www/shop
mkdir -p $S/wp-content/plugins/updraftplus $S/wp-content/plugins/site-health-cache $S/wp-content/themes/shop
echo "<?php // test config" > $S/wp-config.php
printf '<?php\n/*\nPlugin Name: Site Health Cache\nDescription: Small maintenance toolkit: keeps option storage tidy.\n*/\n' > $S/wp-content/plugins/site-health-cache/site-health-cache.php
echo "<?php // theme" > $S/wp-content/themes/shop/functions.php
touch -d "2026-09-01" $S/wp-content/themes/shop/functions.php 2>/dev/null || touch -t 202609010000 $S/wp-content/themes/shop/functions.php
cat > /usr/local/bin/wp <<'WP'
#!/bin/sh
for a in "$@"; do case "$a" in --*) ;; *) set -- "$@" "$a" ;; esac; shift; done
case "$1 $2" in
  "core is-installed") exit 0 ;;
  "option get") [ "$3" = updraft_central_localkeys ] && { echo "(stored keys)"; exit 0; }; exit 1 ;;
  "user list") printf 'user_login\tuser_email\troles\nowner\towner@shop.test\tadministrator\ndata-ops43\tsite-tools@example.org\teditor\nwriter\twriter@shop.test\tauthor\n' ;;
  "user can") case "$3" in owner|data-ops43) exit 0 ;; *) exit 1 ;; esac ;;
esac
WP
chmod +x /usr/local/bin/wp
chown -R nobody $S 2>/dev/null || true
