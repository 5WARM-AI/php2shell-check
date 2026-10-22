# Fixing PHP2Shell

Upgrading PHP is the only complete fix. The temporary measures at the end only buy time.

Fixed releases (21 October 2026): **8.5.12, 8.4.27, 8.3.36, 8.2.35**. PHP 8.1 and older have no official fix, so move them to one of these.

> php.net's ChangeLog page shows 22 October for 8.5.12 and 8.4.27. PHP's release list and the advisories give 21 October.

**Why your version number may look old:** Ubuntu, Debian and Red Hat style distributions add security fixes to their own builds and keep the original version number. `check.sh` reads the package build. If it says PASS with "patched by your distribution", you are fixed even though `php -v` shows an older number.

## Before you change anything

1. Note what you have now: `php -v` and the full `sh check.sh` output.
2. Back up your PHP and web server settings:
   ```sh
   sudo tar czf ~/php-config-backup-$(date +%F).tar.gz /etc/php* /etc/apache2 /etc/httpd /etc/nginx 2>/dev/null
   ```
3. Back up your site's files and database (for WordPress: `wp db export ~/site-db-$(date +%F).sql` run from the site folder, or your host's backup tool).
4. Moving to a different minor version (for example 7.4 to 8.3) can break older sites and plugins. Try it on a copy of the site first if you can.

After any upgrade: restart PHP-FPM and the web server, run `sh check.sh` again and open your site to check it still loads.

## Ubuntu and Debian

### PHP from Ubuntu or Debian itself

```sh
sudo apt update
sudo apt full-upgrade
```

Then restart what serves your site, for example:

```sh
sudo systemctl restart php8.3-fpm     # use your version: php8.1-fpm, php8.2-fpm ...
sudo systemctl restart apache2        # or: sudo systemctl restart nginx
```

Fixed builds published so far:

| Release | Package | Fixed build |
|---|---|---|
| Ubuntu 24.04 | php8.3 | 8.3.6-0ubuntu0.24.04.13 |
| Ubuntu 22.04 | php8.1 | 8.1.2-1ubuntu2.28 |
| Ubuntu 20.04 (Ubuntu Pro) | php7.4 | 7.4.3-4ubuntu2.29+esm5 |
| Debian 12 bookworm | php8.2 | 8.2.35-1~deb12u1 |
| Debian 13 trixie | php8.4 | 8.4.27-1~deb13u1 |

Older Ubuntu releases have fixes only through Ubuntu Pro. Check [Ubuntu's CVE page](https://ubuntu.com/security/CVE-2026-109618) and the [Debian tracker](https://security-tracker.debian.org/tracker/CVE-2026-109618) for your release.

### PHP from Ondřej Surý's packages (ppa:ondrej/php or packages.sury.org)

If you already use these packages, `sudo apt update && sudo apt full-upgrade` installs 8.3.36 and the other fixed releases.

To move an end-of-life PHP to a fixed 8.3 on **Ubuntu**:

```sh
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install php8.3 php8.3-fpm php8.3-cli
```

On **Debian**, follow the repository setup at <https://packages.sury.org/php/README.txt>, then install the same packages.

Install the same extensions you had before (`php -m` on the old version lists them, for example `php8.3-mysql php8.3-curl php8.3-xml php8.3-mbstring php8.3-gd php8.3-zip`). Then point your web server at the new version (for PHP-FPM, the socket in your nginx or Apache config changes to `php8.3-fpm.sock`) and restart it.

## RHEL, AlmaLinux and Rocky Linux

### PHP from Remi's repository

Remi did not have the fix on 21 October (Sansec, Help Net Security). It has since published 8.3.36 for EL9. Update and check the version:

```sh
sudo dnf upgrade 'php*'
php -v
```

To move to a fixed 8.3 with Remi's module stream:

```sh
sudo dnf module reset php
sudo dnf module enable php:remi-8.3
sudo dnf upgrade 'php*'
```

Then restart: `sudo systemctl restart php-fpm httpd` (or `nginx`).

### PHP from the distribution itself (AppStream)

```sh
sudo dnf updateinfo list --cve CVE-2026-109618
sudo dnf upgrade 'php*'
```

If no update lists these CVEs, ask your vendor, or move to a fixed release from another package source.

## Docker (official `php` images)

Change your `Dockerfile` or Compose file to a fixed tag:

```Dockerfile
FROM php:8.3.36-fpm
# or php:8.2.35-..., php:8.4.27-..., php:8.5.12-... with the variant you use (-cli, -fpm, -apache, -fpm-alpine ...)
```

Rebuild and restart:

```sh
docker compose build --pull
docker compose up -d
```

Then run `sh check.sh` on the host again; it checks running containers too.

## cPanel and Plesk

- **cPanel / WHM:** update the EasyApache PHP packages (`sudo dnf upgrade 'ea-php*'`, or `yum` on older systems), or ask your host. Use WHM's MultiPHP Manager to move sites off PHP 8.1 and older.
- **Plesk:** install the latest PHP updates under Tools & Settings > Updates, then switch sites off PHP 8.1 and older in each domain's PHP Settings.

Run `sh check.sh` afterwards. If a panel PHP still shows below the fixed release, contact the panel vendor or your host.

## Managed hosting: send them this

If you cannot change PHP yourself, send your host this email:

> Subject: PHP2Shell (CVE-2026-109618, CVE-2026-109619) on my hosting
>
> Hello,
>
> Please confirm which PHP version and setup (PHP-FPM, mod_php, LiteSpeed or other) serve my website, and whether it includes the fixes for CVE-2026-109618 and CVE-2026-109619. PHP's fixed releases are 8.5.12, 8.4.27, 8.3.36 and 8.2.35, and PHP 8.1 and older have no official fix.
>
> If my site is on an affected or end-of-life version, please move it to a fixed release, restart the PHP workers, and tell me when it is done.
>
> Thank you.

## WordPress: UpdraftCentral keys

Patchstack reports that stolen UpdraftCentral dashboard keys are being used to install backdoor plugins. This is separate from PHP2Shell. If `check.sh --wordpress` warns about UpdraftPlus or UpdraftCentral:

1. Delete the site's UpdraftCentral keys: wp-admin > Settings > UpdraftPlus Backups > Advanced Tools > UpdraftCentral > Manage existing keys, and delete each one. With WP-CLI: `wp option delete updraft_central_localkeys`. Backups keep working.
2. Don't reconnect to UpdraftCentral until the vendor explains the cause.
3. If the check reports files matching the published backdoor, treat the site as compromised: follow [Patchstack's steps](https://patchstack.com/articles/updraftcentral-key-compromise-wordpress-backdoors/), restore from a backup made before the attack, and change every password.

## Temporary measures while you arrange the upgrade

These reduce the risk for a short time. Remove or undo them once PHP is upgraded.

### PHP settings (from PHP's own advice, via Tenable)

- For CVE-2026-109618: set `memory_limit=-1` in a way applications cannot override.
- For CVE-2026-109619: set `session.upload_progress.enabled=0`, and on PHP 8.5 also `fatal_error_backtraces=0`.
- Restart every PHP worker afterwards.

Sansec warns these are partial, that turning off upload progress alone is not enough, and that `memory_limit = -1` lets one request use all the server's memory, so watch memory use. Sansec's PHP-FPM pool form:

```
php_admin_flag[session.upload_progress.enabled] = off
php_admin_value[memory_limit] = -1
```

### Block file-upload requests (from Sansec)

These rules block every `multipart/form-data` request. **File uploads will stop working, and some checkout forms too.** Remove them after upgrading PHP.

Sansec's nginx rule (in each `server` block that passes requests to PHP, then reload nginx):

```nginx
if ($http_content_type ~* "multipart/form-data") {
    return 403;
}
```

Sansec's Apache rule (in each `<VirtualHost>` that serves PHP, then reload Apache):

```apache
RewriteEngine On
RewriteCond %{HTTP:Content-Type} multipart/form-data [NC]
RewriteRule ^ - [F]
```

Credit: [Sansec, PHP2Shell](https://sansec.io/research/php2shell).

### Cloudflare

Cloudflare has deployed managed WAF rules for the known exploit routes on sites it proxies, and calls them a stopgap (Tenable, Patchstack). They only help if your server accepts traffic from Cloudflare alone. No source publishes a custom Cloudflare rule for this, so none is given here.

---

Swarm | [5warm.ai](https://5warm.ai)
