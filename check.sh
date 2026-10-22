#!/bin/sh
# php2shell-check: read-only self-check for PHP2Shell (CVE-2026-109618, CVE-2026-109619).
# Run it on your own server. It changes nothing, sends nothing and probes no other host.
#
#   sh check.sh                    check every PHP install on this server
#   sh check.sh --wordpress [DIR]  also run the WordPress checks (DIR = site folder; default: search common places)
#   sh check.sh --no-docker        skip running containers
#
# Exit code: 0 all clear, 1 at least one VULNERABLE or END-OF-LIFE install (or a WordPress backdoor match),
# 2 something needs a manual check (CHECK, or a WordPress warning).
# MIT licence. Swarm | 5warm.ai

LC_ALL=C
export LC_ALL

# Fixed upstream releases, 21 Oct 2026 (php.net; GHSA-w8hw-w9fx-j79w, GHSA-6wmf-4rv5-p3rp).
FIXED="8.5.12 8.4.27 8.3.36 8.2.35"

# Distribution builds that carry the fix under an older version number.
# package | marker in the version string | first fixed build | source
DISTRO_FIXED='php8.3|ubuntu0.24.04|8.3.6-0ubuntu0.24.04.13|ubuntu.com/security/CVE-2026-109618
php8.1|ubuntu2|8.1.2-1ubuntu2.28|ubuntu.com/security/CVE-2026-109618
php7.4|ubuntu2|7.4.3-4ubuntu2.29+esm5|ubuntu.com/security/CVE-2026-109618 (Ubuntu Pro)
php7.2|ubuntu0.18.04|7.2.24-0ubuntu0.18.04.17+esm14|ubuntu.com/security/CVE-2026-109618 (Ubuntu Pro)
php7.0|ubuntu0.16.04|7.0.33-0ubuntu0.16.04.16+esm22|ubuntu.com/security/CVE-2026-109618 (Ubuntu Pro)
php5|ubuntu4|5.5.9+dfsg-1ubuntu4.29+esm18|ubuntu.com/security/CVE-2026-109618 (Ubuntu Pro)
php8.5|ubuntu1.|8.5.4-0ubuntu1.5|ubuntu.com/security/CVE-2026-109618
php8.5|ubuntu2.|8.5.9-0ubuntu2.1|ubuntu.com/security/CVE-2026-109618
php8.2|deb12u|8.2.35-1~deb12u1|security-tracker.debian.org/tracker/CVE-2026-109618
php8.4|deb13u|8.4.27-1~deb13u1|security-tracker.debian.org/tracker/CVE-2026-109618'

DO_WP=0
WP_DIR=""
DO_DOCKER=1
while [ $# -gt 0 ]; do
  case "$1" in
    (--wordpress) DO_WP=1
      case "${2:-}" in (""|-*) ;; (*) WP_DIR=$2; shift ;; esac ;;
    (--no-docker) DO_DOCKER=0 ;;
    (-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    (*) echo "Unknown option: $1 (try --help)"; exit 64 ;;
  esac
  shift
done

N_PASS=0; N_VULN=0; N_EOL=0; N_CHECK=0; N_WP_DANGER=0; N_WP_WARN=0
SEEN=" "

say() { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

realpath_of() {
  if have readlink && readlink -f "$1" >/dev/null 2>&1; then readlink -f "$1"; else printf '%s\n' "$1"; fi
}

# First x.y.z after "PHP " or "PHP/" in some text.
php_version_in() {
  sed -n 's/.*PHP[ \/]v\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1
}

# Version of a binary: ask it, then fall back to the version string compiled into it.
binary_version() {
  bv_bin=$1
  bv_v=""
  case "$bv_bin" in
    (*frankenphp*) bv_v=$("$bv_bin" version 2>/dev/null | php_version_in) ;;
    (*.so) ;;
    (*) bv_v=$("$bv_bin" -v 2>/dev/null | php_version_in) ;;
  esac
  if [ -z "$bv_v" ] && [ -r "$bv_bin" ]; then
    bv_v=$(grep -a -o 'X-Powered-By: PHP/[0-9][0-9.]*' "$bv_bin" 2>/dev/null | php_version_in)
  fi
  printf '%s\n' "$bv_v"
}

# Package that owns a file, and its version (empty when not from a package).
package_info() {
  pi_f=$1
  if have dpkg-query; then
    pi_pkg=$(dpkg-query -S "$pi_f" 2>/dev/null | head -n 1 | cut -d: -f1)
    if [ -n "$pi_pkg" ]; then
      printf 'deb %s %s\n' "$pi_pkg" "$(dpkg-query -W -f='${Version}' "$pi_pkg" 2>/dev/null)"
      return
    fi
  fi
  if have rpm; then
    pi_r=$(rpm -qf --qf '%{NAME} %{VERSION}-%{RELEASE}\n' "$pi_f" 2>/dev/null | head -n 1)
    case "$pi_r" in (""|*"not owned"*|*"No such"*) ;; (*) printf 'rpm %s\n' "$pi_r"; return ;; esac
  fi
  if have apk; then
    pi_a=$(apk info --who-owns "$pi_f" 2>/dev/null | sed -n 's/.* is owned by //p' | head -n 1)
    [ -n "$pi_a" ] && { printf 'apk %s\n' "$pi_a"; return; }
  fi
  printf '\n'
}

# 0 when x.y.z $1 >= $2
ver_ge() {
  vg_a1=$(echo "$1" | cut -d. -f1); vg_a2=$(echo "$1" | cut -d. -f2); vg_a3=$(echo "$1" | cut -d. -f3)
  vg_b1=$(echo "$2" | cut -d. -f1); vg_b2=$(echo "$2" | cut -d. -f2); vg_b3=$(echo "$2" | cut -d. -f3)
  [ "$vg_a1" -gt "$vg_b1" ] && return 0; [ "$vg_a1" -lt "$vg_b1" ] && return 1
  [ "$vg_a2" -gt "$vg_b2" ] && return 0; [ "$vg_a2" -lt "$vg_b2" ] && return 1
  [ "$vg_a3" -ge "$vg_b3" ]
}

# Prints "PASS|VULNERABLE|END-OF-LIFE|CHECK<tab>explanation"
verdict() {
  vd_v=$1; vd_kind=$2; vd_pkg=$3; vd_pver=$4
  vd_mm=$(echo "$vd_v" | cut -d. -f1-2)
  vd_major=$(echo "$vd_v" | cut -d. -f1); vd_minor=$(echo "$vd_v" | cut -d. -f2)

  # Distribution builds: the upstream number can be old while the fix is in.
  if [ "$vd_kind" = deb ]; then
    case "$vd_pver" in
      (*deb.sury.org*) ;;   # Ondrej Sury builds follow upstream numbers
      (*)
        vd_src=$(echo "$vd_pkg" | sed -n 's/.*\(php[0-9][0-9.]*\).*/\1/p' | sed 's/\.$//')
        vd_line=$(printf '%s\n' "$DISTRO_FIXED" | while IFS='|' read -r p m f s; do
          [ "$p" = "$vd_src" ] || continue
          # same distribution build line, or the same upstream base version (e.g. an older 8.3.6-0... build)
          case "$vd_pver" in
            (*"$m"*|"${f%%-*}"-*) printf '%s|%s\n' "$f" "$s"; break ;;
          esac
        done)
        if [ -n "$vd_line" ]; then
          vd_fix=${vd_line%%|*}; vd_s=${vd_line#*|}
          if ! have dpkg && [ "$vd_pver" != "$vd_fix" ]; then
            printf 'CHECK\tDistribution package %s %s. The fixed build is %s or newer (%s), and this server has no dpkg to compare the two. Run "dpkg --compare-versions %s ge %s && echo fixed" inside it.\n' "$vd_pkg" "$vd_pver" "$vd_fix" "$vd_s" "$vd_pver" "$vd_fix"
            return
          fi
          if [ "$vd_pver" = "$vd_fix" ] || dpkg --compare-versions "$vd_pver" ge "$vd_fix" 2>/dev/null; then
            if [ "$vd_major" -lt 8 ] || { [ "$vd_major" -eq 8 ] && [ "$vd_minor" -lt 2 ]; }; then
              printf 'PASS\tPatched by your distribution (fixed from build %s; %s). PHP %s itself is end-of-life, so plan a move to 8.2 or newer.\n' "$vd_fix" "$vd_s" "$vd_mm"
            else
              printf 'PASS\tPatched by your distribution (fixed from build %s; %s).\n' "$vd_fix" "$vd_s"
            fi
          else
            printf 'VULNERABLE\tYour distribution has a fix (%s or newer; %s). You have %s. Install your system updates (see FIX.md).\n' "$vd_fix" "$vd_s" "$vd_pver"
          fi
          return
        fi
        case "$vd_pver" in
          (*ubuntu*|*deb[0-9]*u*|*debian*)
            printf 'CHECK\tDistribution package %s %s. Distributions often fix PHP without changing its version number, and this build is not in our table. Look up "CVE-2026-109618" on your distribution security page.\n' "$vd_pkg" "$vd_pver"
            return ;;
        esac ;;
    esac
  fi
  if [ "$vd_kind" = rpm ]; then
    case "$vd_pver" in
      (*remi*|*cpanel*|*plesk*|*ea[0-9]*) ;;   # these follow upstream numbers
      (*.el[0-9]*|*.fc[0-9]*|*.amzn*)
        printf 'CHECK\tDistribution package %s %s. Red Hat style distributions fix PHP without changing its version number. Run "dnf updateinfo list --cve CVE-2026-109618" (or ask your vendor) to see if this build has the fix.\n' "$vd_pkg" "$vd_pver"
        return ;;
    esac
  fi

  if [ "$vd_major" -lt 5 ] || { [ "$vd_major" -eq 5 ] && [ "$vd_minor" -lt 4 ]; }; then
    printf 'END-OF-LIFE\tPHP %s is far past end-of-life and gets no security fixes. Move to a fixed PHP 8 release.\n' "$vd_v"; return
  fi
  if [ "$vd_major" -lt 8 ] || { [ "$vd_major" -eq 8 ] && [ "$vd_minor" -lt 2 ]; }; then
    printf 'END-OF-LIFE\tPHP %s is end-of-life. The PHP project has no release that fixes PHP2Shell for %s. Move to 8.2.35, 8.3.36, 8.4.27, 8.5.12 or newer.\n' "$vd_v" "$vd_mm"; return
  fi
  for vd_f in $FIXED; do
    if [ "$(echo "$vd_f" | cut -d. -f1-2)" = "$vd_mm" ]; then
      if ver_ge "$vd_v" "$vd_f"; then
        printf 'PASS\tPHP %s includes the fix (fixed from %s).\n' "$vd_v" "$vd_f"
      else
        printf 'VULNERABLE\tPHP %s is affected. Upgrade to %s or newer.\n' "$vd_v" "$vd_f"
      fi
      return
    fi
  done
  printf 'PASS\tPHP %s is newer than every affected branch.\n' "$vd_v"
}

report() {
  rp_where=$1; rp_what=$2; rp_v=$3; rp_kind=$4; rp_pkg=$5; rp_pver=$6
  if [ -z "$rp_v" ]; then
    N_CHECK=$((N_CHECK + 1))
    say "  CHECK        $rp_where"
    say "               $rp_what. Could not read its PHP version. Run it with sudo, or ask your host which PHP version it uses."
    return
  fi
  rp_out=$(verdict "$rp_v" "$rp_kind" "$rp_pkg" "$rp_pver")
  rp_res=$(printf '%s' "$rp_out" | cut -f1)
  rp_msg=$(printf '%s' "$rp_out" | cut -f2-)
  case "$rp_res" in
    (PASS) N_PASS=$((N_PASS + 1)) ;;
    (VULNERABLE) N_VULN=$((N_VULN + 1)) ;;
    (END-OF-LIFE) N_EOL=$((N_EOL + 1)) ;;
    (*) N_CHECK=$((N_CHECK + 1)) ;;
  esac
  say "  $(printf '%-12s' "$rp_res") $rp_where"
  say "               $rp_what, PHP $rp_v. $rp_msg"
}

check_file() {
  cf_f=$1; cf_what=$2
  [ -e "$cf_f" ] || return
  cf_real=$(realpath_of "$cf_f")
  case "$SEEN" in (*" $cf_real "*) return ;; esac
  SEEN="$SEEN$cf_real "
  cf_v=$(binary_version "$cf_real")
  cf_info=$(package_info "$cf_real")
  # shellcheck disable=SC2086 # split "kind package version" on purpose
  set -- $cf_info
  [ -n "${2:-}" ] && cf_what="$cf_what, package ${2}${3:+ $3}"
  report "$cf_f" "$cf_what" "$cf_v" "${1:-}" "${2:-}" "${3:-}"
}

describe() {
  case "$1" in
    (*frankenphp*) echo "FrankenPHP" ;;
    (*lsphp*) echo "LiteSpeed PHP (lsphp)" ;;
    (*php-fpm*|*php*-fpm*) echo "PHP-FPM (web)" ;;
    (*php-cgi*|*php*-cgi*) echo "php-cgi (web)" ;;
    (*libphp*|*mod_php*) echo "Apache mod_php (web)" ;;
    (*) echo "PHP command line" ;;
  esac
}

say "PHP2Shell self-check (CVE-2026-109618, CVE-2026-109619)"
say "Read-only. Fixed PHP releases: 8.2.35, 8.3.36, 8.4.27, 8.5.12."
if [ "$(id -u)" -ne 0 ]; then
  say "Running without sudo. That works, but 'sudo sh check.sh' also sees Docker containers and files other users own."
fi
say ""
say "PHP on this server"

# Commands on PATH
OLDIFS=$IFS; IFS=:
for d in $PATH; do
  IFS=$OLDIFS
  for f in "$d"/php "$d"/php[0-9]* "$d"/php-fpm* "$d"/php[0-9]*-fpm* "$d"/php-cgi* "$d"/php[0-9]*-cgi* "$d"/lsphp* "$d"/frankenphp; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    case "$f" in (*.dpkg-*|*-config*|*ize*|*dbg*) continue ;; esac
    check_file "$f" "$(describe "$f")"
  done
  IFS=:
done
IFS=$OLDIFS

# Common install places for distributions, control panels, extra repos and LiteSpeed
for f in /usr/bin/php[0-9]* /usr/sbin/php-fpm* /usr/local/sbin/php-fpm* \
         /opt/remi/php*/root/usr/bin/php* /opt/remi/php*/root/usr/sbin/php-fpm* \
         /opt/cpanel/ea-php*/root/usr/bin/php* /opt/cpanel/ea-php*/root/usr/sbin/php-fpm* \
         /opt/plesk/php/*/bin/php* /opt/plesk/php/*/sbin/php-fpm* \
         /opt/alt/php*/usr/bin/php* /opt/alt/php*/usr/sbin/php-fpm* \
         /usr/local/lsws/lsphp*/bin/lsphp* /usr/local/lsws/fcgi-bin/lsphp* \
         /usr/local/php*/bin/php* /usr/local/php*/sbin/php-fpm* \
         /usr/local/bin/frankenphp /usr/bin/frankenphp; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  case "$f" in (*.dpkg-*|*-config*|*ize*|*dbg*) continue ;; esac
  check_file "$f" "$(describe "$f")"
done

# Apache mod_php
for f in /usr/lib/apache2/modules/libphp*.so /usr/lib64/httpd/modules/libphp*.so /usr/lib/httpd/modules/libphp*.so \
         /etc/httpd/modules/libphp*.so /usr/local/apache2/modules/libphp*.so /usr/local/apache/modules/libphp*.so; do
  [ -f "$f" ] || continue
  check_file "$f" "Apache mod_php (web)"
done
for c in apache2ctl apachectl httpd; do
  if have "$c"; then
    mods=$("$c" -M 2>/dev/null | grep -i 'php' | sed 's/^ *//')
    [ -n "$mods" ] && say "  (Apache reports these PHP modules loaded: $(echo "$mods" | tr '\n' ' '))"
    break
  fi
done

if [ $((N_PASS + N_VULN + N_EOL + N_CHECK)) -eq 0 ]; then
  say "  No PHP found on this server."
fi

# Running Docker containers
if [ "$DO_DOCKER" -eq 1 ] && have docker; then
  if ! ids=$(docker ps -q 2>/dev/null); then
    say ""
    say "Docker is installed, but this user cannot list containers. Run with sudo to check them."
  elif [ -n "$ids" ]; then
    say ""
    say "PHP inside running Docker containers"
    for id in $ids; do
      name=$(docker inspect -f '{{.Name}} ({{.Config.Image}})' "$id" 2>/dev/null | sed 's/^\///')
      # Ask the container for its PHP version and, on Debian/Ubuntu images, the package that owns it.
      out=$(docker exec "$id" sh -c 'for b in php php-fpm frankenphp; do p=$(command -v $b 2>/dev/null) || continue; if [ $b = frankenphp ]; then $b version; else $b -v; fi; if command -v dpkg-query >/dev/null 2>&1; then k=$(dpkg-query -S "$(readlink -f "$p")" 2>/dev/null | head -n 1 | cut -d: -f1); [ -n "$k" ] && echo "@@deb $k $(dpkg-query -W -f="\${Version}" "$k")"; fi; break; done' 2>/dev/null)
      v=$(printf '%s\n' "$out" | php_version_in)
      if [ -z "$v" ]; then
        say "  no PHP       container $name"
        continue
      fi
      # shellcheck disable=SC2046 # split "kind package version" on purpose
      set -- $(printf '%s\n' "$out" | sed -n 's/^@@//p' | head -n 1)
      report "container $name" "PHP in a container${2:+, package $2 ${3:-}}" "$v" "${1:-}" "${2:-}" "${3:-}"
    done
  fi
fi

# WordPress
if [ "$DO_WP" -eq 1 ]; then
  say ""
  say "WordPress checks"
  if [ -n "$WP_DIR" ]; then
    sites=$(find "$WP_DIR" -maxdepth 4 -name wp-config.php 2>/dev/null)
  else
    sites=$(find /var/www /srv/www /home /usr/share/nginx/html -maxdepth 5 -name wp-config.php 2>/dev/null)
  fi
  if [ -z "$sites" ]; then
    say "  No WordPress site found. Pass the site folder: sh check.sh --wordpress /path/to/site"
  fi
  for cfg in $sites; do
    site=$(dirname "$cfg")
    wpc="$site/wp-content"
    say ""
    say "  Site: $site"
    [ -d "$wpc" ] || { say "    No wp-content folder here."; continue; }

    if [ -d "$wpc/plugins/updraftplus" ] || [ -d "$wpc/plugins/updraftcentral" ]; then
      N_WP_WARN=$((N_WP_WARN + 1))
      say "    WARNING  UpdraftPlus or UpdraftCentral is installed."
      say "             Patchstack reports stolen UpdraftCentral dashboard keys being used to install backdoor plugins."
      say "             Delete this site's UpdraftCentral keys: wp-admin > Settings > UpdraftPlus Backups > Advanced Tools >"
      say "             UpdraftCentral > Manage existing keys, then delete each key. Your backups keep working."
    else
      say "    OK       No UpdraftPlus or UpdraftCentral plugin folder."
    fi

    hits=$(grep -rl "Small maintenance toolkit: keeps option storage tidy" "$wpc/plugins" 2>/dev/null; \
           grep -rlE "Plugin Name:[[:space:]]*Site Health Cache" "$wpc/plugins" 2>/dev/null)
    if [ -n "$hits" ]; then
      N_WP_DANGER=$((N_WP_DANGER + 1))
      say "    DANGER   Files match a backdoor Patchstack published. Treat the site as compromised (see FIX.md, WordPress):"
      printf '%s\n' "$hits" | sort -u | sed 's/^/             /'
    else
      say "    OK       No files match the published backdoor text."
    fi

    recent=$(find "$wpc" -name '*.php' -type f -mtime -7 2>/dev/null)
    n=$(printf '%s' "$recent" | grep -c . 2>/dev/null)
    if [ "${n:-0}" -gt 0 ]; then
      say "    REVIEW   $n PHP file(s) in wp-content changed in the last 7 days. Updates cause this too; check any you don't recognise:"
      printf '%s\n' "$recent" | head -n 25 | sed 's/^/             /'
      [ "$n" -gt 25 ] && say "             ...and $((n - 25)) more."
    else
      say "    OK       No PHP files in wp-content changed in the last 7 days."
    fi

    if have wp && [ "$(id -u)" -ne 0 ]; then
      wpq="wp --path=$site --skip-plugins --skip-themes --quiet"
      if $wpq option get updraft_central_localkeys >/dev/null 2>&1; then
        N_WP_WARN=$((N_WP_WARN + 1))
        say "    WARNING  This site has UpdraftCentral keys stored (updraft_central_localkeys). Delete them as described above."
      fi
      say "    REVIEW   Users who can change settings or install plugins. Check you know every one:"
      $wpq user list --fields=user_login,user_email,roles 2>/dev/null | while IFS= read -r line; do
        login=$(printf '%s' "$line" | awk '{print $1}')
        [ "$login" = user_login ] && continue
        if $wpq user can "$login" manage_options >/dev/null 2>&1 || $wpq user can "$login" install_plugins >/dev/null 2>&1; then
          flag=""
          printf '%s' "$line" | grep -Eq '^[a-z]+-[a-z]+[0-9][0-9][[:space:]]|@example\.org' && flag="  <- matches the backdoor account pattern Patchstack published"
          say "             $line$flag"
        fi
      done
    elif have wp; then
      say "    SKIPPED  User and key checks. WP-CLI runs the site's own code, so run this part as the site's user, without sudo."
    else
      say "    SKIPPED  User and key checks need WP-CLI. Without it: in wp-admin > Users, filter by Administrator and check you know every account."
    fi
  done
fi

say ""
say "Summary: $N_PASS pass, $N_VULN vulnerable, $N_EOL end-of-life, $N_CHECK need a manual check."
if [ "$DO_WP" -eq 1 ]; then
  say "WordPress: $N_WP_DANGER danger, $N_WP_WARN warning(s)."
  [ "$N_WP_DANGER" -gt 0 ] && say "Action: a site matches a published backdoor. Follow the WordPress section of FIX.md before anything else."
fi
if [ $((N_VULN + N_EOL + N_WP_DANGER)) -gt 0 ]; then
  [ $((N_VULN + N_EOL)) -gt 0 ] && say "Action: upgrade now. FIX.md has copy-paste steps, and a ready email if your host manages PHP for you."
  [ $((N_VULN + N_EOL)) -gt 0 ] && say "After upgrading, restart PHP-FPM and your web server, then run this check again."
  exit 1
fi
if [ $((N_CHECK + N_WP_WARN)) -gt 0 ]; then
  say "Action: follow the note next to each CHECK or WARNING."
  exit 2
fi
exit 0
