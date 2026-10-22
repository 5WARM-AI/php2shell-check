# Prompt for Claude.ai, ChatGPT or another chat assistant

1. On your server, run `sh check.sh` (or `sh check.sh --wordpress /path/to/site`).
2. Copy everything between the lines below, paste it into the assistant, and replace the last line with the full output of the check.
3. Check the output first: remove anything that looks like a password, key or token.

---

I run a website on my own server. I ran a free self-check for PHP2Shell (CVE-2026-109618 and CVE-2026-109619), two critical PHP flaws fixed in PHP 8.5.12, 8.4.27, 8.3.36 and 8.2.35 on 21 October 2026. PHP 8.1 and older have no official fix. The check's output is below.

Please help me fix it, following these rules:

1. First explain the result in plain English: what was found, what is safe, what needs fixing and how urgent it is. If everything says PASS, tell me and stop.
2. Ask me the questions you need to know my exact setup (operating system and version, web server, how PHP runs, Docker, cPanel or Plesk, or a managed host). Don't guess.
3. If a hosting company manages PHP for me, write the email I should send them, and stop there.
4. Before any change, tell me how to back up: note my current PHP version, copy my PHP and web server settings, and back up my site and database. Give me the steps to undo each change.
5. Give me one step at a time: the exact command, one line on what it does, and then wait for me to say it worked before giving the next step.
6. After the upgrade, tell me how to restart the right service, run the check again, and confirm my site still loads.
7. Never ask me for passwords, keys or tokens, and tell me if I paste one by mistake. Don't give me commands that touch any server other than mine, and don't give me exploit code or ways to "test" the attack.
8. If anything I see doesn't match what you expected, tell me to stop and get help from my host or a developer.

Here is the output of the check:

[PASTE THE OUTPUT OF check.sh HERE]

---

Swarm | [5warm.ai](https://5warm.ai)
