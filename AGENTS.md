# Instructions for AI coding agents

You are helping a site owner check their own server for PHP2Shell (CVE-2026-109618, CVE-2026-109619) and fix it. Many owners are not developers. Use plain English, keep each message short, and follow these rules exactly.

## 1. Check first

- Run `sh check.sh` (add `--wordpress <site folder>` for a WordPress site) before suggesting anything.
- Explain the result in plain English: which PHP installs were found, which are PASS, VULNERABLE, END-OF-LIFE or CHECK, and what that means for this site.
- If everything is PASS, say so and stop.

## 2. Find out the setup

Work out, read-only, which of these applies, and say what you found:

- operating system and release (`cat /etc/os-release`)
- web server (Apache, nginx, LiteSpeed, Caddy/FrankenPHP)
- how PHP runs (PHP-FPM, mod_php, php-cgi, lsphp)
- Docker, cPanel or Plesk
- a managed host where the owner cannot change PHP

Use only the matching section of FIX.md.

- **Managed host:** draft the email to the host from FIX.md, show it to the owner, and stop. Don't send it.
- **If the setup doesn't match any FIX.md section, or anything you see differs from what FIX.md describes:** stop and tell the owner to get help from their host or a developer. Don't improvise.

## 3. Back up before any change

Before the first change, propose a backup and wait for a yes:

- note the current PHP version (`php -v`) and save the full `check.sh` output
- copy the PHP and web server config (`/etc/php*`, `/etc/apache2` or `/etc/httpd`, `/etc/nginx`)
- for WordPress, a database export (`wp db export`) and a copy of the site files, or the host's backup tool

Give the rollback steps for the change you are about to make (for example: reinstall the previous package version, restore the config backup, switch the web server back to the old PHP-FPM socket, restart).

## 4. One step at a time, with a yes each time

- Before ANY command that changes the system (installing, upgrading, editing a file, restarting a service), show the exact command, say in one line what it does, and ask "Shall I run this?"
- Wait for the owner's yes. One step per yes. If they say no or seem unsure, stop.
- Read-only commands (`php -v`, `cat`, `sh check.sh`, `systemctl status`) can run without asking.

## 5. After the upgrade

- Restart the service that serves the site (PHP-FPM, Apache, nginx, LiteSpeed or the container), after a yes.
- Run `sh check.sh` again and show the result.
- Confirm the site still loads, for example with `curl -sS -o /dev/null -w '%{http_code}\n' https://<their own site>`. Ask the owner to open it in a browser too.
- Remind them to undo any temporary measure from FIX.md (upload-blocking rules, `memory_limit=-1`).

## 6. Never

- Never ask for, read out or print passwords, API keys, tokens, database credentials or private keys. If a command would print one, don't run it. If a secret shows up in output, don't repeat it and tell the owner to change it.
- Never scan, probe or connect to any server other than the owner's own, and only the one you are working on.
- Never download, write or run exploit code or a proof-of-concept, including to "test" the fix. `check.sh` is the test.
- Never disable security software, firewalls or backups to make a step work.

## 7. When to stop

Stop and tell the owner to get help if a command fails in a way FIX.md doesn't cover, the site stops loading and the rollback doesn't bring it back, the WordPress check reports files matching the published backdoor, or you are unsure what something does.
