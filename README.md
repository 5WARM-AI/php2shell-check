# PHP2Shell self-check

**What it is:** a free script that tells you if the PHP on your own server is exposed to PHP2Shell (CVE-2026-109618 and CVE-2026-109619), two critical flaws that let an attacker take over a server with no password.
**Run it:** copy `check.sh` to your server and type `sh check.sh`.
**If it says VULNERABLE or END-OF-LIFE:** upgrade PHP today using [FIX.md](FIX.md). If a hosting company runs PHP for you, send them the email in FIX.md.
**Full guide:** [5warm.ai/guides/php2shell-check/](https://5warm.ai/guides/php2shell-check/)

---

## What it does

`check.sh` looks at the server it runs on and lists every PHP it finds:

- PHP on the command line, PHP-FPM, php-cgi, Apache mod_php, FrankenPHP and LiteSpeed (lsphp)
- PHP installed by cPanel, Plesk, CloudLinux, Remi and Ondřej Surý's packages
- PHP inside running Docker containers, if Docker is installed

For each one it prints a result in plain English:

| Result | Meaning |
|---|---|
| PASS | This PHP has the fix. |
| VULNERABLE | This PHP is affected. Upgrade it. |
| END-OF-LIFE | This PHP version gets no official fix. Move to PHP 8.2 or newer. |
| CHECK | The script could not decide. The note next to it says what to look up. |

It is read-only. It changes nothing, sends nothing anywhere and looks only at the server it runs on. It works without sudo; with `sudo sh check.sh` it can also see Docker containers and files that belong to other users.

### WordPress sites

```sh
sh check.sh --wordpress /path/to/your/site
```

This adds checks for the separate UpdraftCentral incident Patchstack reported, where stolen dashboard keys were used to install backdoor plugins. It looks for the UpdraftPlus and UpdraftCentral plugins, the backdoor text Patchstack published, PHP files in `wp-content` changed in the last 7 days, and (with WP-CLI) the users who can change settings or install plugins.

### Exit codes

`0` all clear, `1` something is VULNERABLE or END-OF-LIFE (or a WordPress site matches the published backdoor), `2` something needs a manual check (CHECK, or a WordPress warning).

## Fixed PHP releases

PHP released fixes on 21 October 2026:

| Branch | Fixed in |
|---|---|
| 8.5 | 8.5.12 |
| 8.4 | 8.4.27 |
| 8.3 | 8.3.36 |
| 8.2 | 8.2.35 |
| 8.1 and older | No official release. Move to one of the versions above. |

Linux distributions such as Ubuntu and Debian often add the fix to their own builds and keep the older version number, so Ubuntu 24.04's fixed PHP still says 8.3.6. The script reads the package build to tell these apart.

## Use it with an AI assistant

- **Claude Code, Codex, Cursor or another coding agent:** open this folder (or copy it to your server) and ask the agent to check your server for PHP2Shell. [AGENTS.md](AGENTS.md) tells it to run the check first, explain the result, back up, and wait for your yes before every change.
- **Claude.ai, ChatGPT or another chat assistant:** run `sh check.sh`, then paste the prompt in [PROMPT.md](PROMPT.md) together with the output. The assistant then walks you through the fix for your setup one step at a time.

Never paste passwords, keys or tokens into any assistant.

## Sources

- PHP security advisories [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) (CVE-2026-109618) and [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) (CVE-2026-109619), and the [php.net release list](https://www.php.net/releases/)
- [Tenable: PHP2Shell FAQ](https://www.tenable.com/blog/php2shell-cve-2026-109618-cve-2026-109619-frequently-asked-questions-about-critical-php-remote)
- [Help Net Security](https://www.helpnetsecurity.com/2026/10/21/php2shell-php-vulnerabilities-patched-cve-2026-109618-cve-2026-109619/)
- [Sansec: PHP2Shell](https://sansec.io/research/php2shell)
- [Patchstack: PHP vulnerability alert](https://patchstack.com/articles/php-major-vulnerability-alert-10-2026/) and [UpdraftCentral key compromise](https://patchstack.com/articles/updraftcentral-key-compromise-wordpress-backdoors/)
- [Ubuntu CVE-2026-109618](https://ubuntu.com/security/CVE-2026-109618) and [Debian security tracker](https://security-tracker.debian.org/tracker/CVE-2026-109618)

## Licence

MIT. See [LICENSE](LICENSE).

---

Swarm | [5warm.ai](https://5warm.ai)
