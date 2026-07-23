# Docker image for SnappyMail

SnappyMail is an actively maintained fork of RainLoop. This image replaces the
abandoned RainLoop Community Edition with a drop-in equivalent that supports PHP 8.

Best used as webmail frontend in https://github.com/mwaeckerlin/mailservice

Two images are built:
1. `mwaeckerlin/snappymail:nginx` — nginx proxy serving static files, forwarding PHP
2. `mwaeckerlin/snappymail:php-fpm` — PHP-FPM container running the app

Check `docker-compose.yml` for a usage example.


## Local Testing

```bash
npm start
```

Then open: http://localhost:8080/


## Volumes

Store permanently:
- `data`: `/app/data` — all configuration, accounts, cached state


## Configuration

Open the admin panel at http://localhost:8080/?admin

Default admin credentials:
- User: `admin`
- Password: `12345`

**Important:** Change the admin password immediately!


### IMAP / SMTP Server

In the admin panel → *Domains* → *Add domain*:
- IMAP host: your dovecot hostname, port 143 (or 993 for TLS)
- SMTP host: your postfix hostname, port 25 (or 587 for submission)


## Transport-security plugin

The image bundles a SnappyMail plugin (`plugins/transport-security/`)
that marks how securely each incoming mail was transported. It reads the
`X-Transport-Security` header the mailservice MX stamps on every incoming
mail and shows, at the top of the opened message, a red «UNENCRYPTED»
banner for a cleartext hop, an orange banner for an obsolete TLS version,
and nothing for TLS 1.2+.

SnappyMail loads plugins from the data volume, and the php-fpm image is
headless, so the plugin ships staged at `/opt/snappymail-plugins/` and is
installed into the data volume and enabled by the init container built
from `Dockerfile.plugin-init` (`install-plugins.sh`) — run it against the
same `snappymail-data` volume before starting the app (see
`mwaeckerlin/mailservice`'s `docker-compose.local.yml` for the wiring).
Pinned by the mailservice e2e suite (`test_webui.py`): the red banner
appears for a plaintext-delivered mail and is absent for a TLS-submitted
one.


### Database for Contacts

Admin panel → *Contacts* → configure:
- Type: `MySQL`
- DSN: `mysql:host=mysql;port=3306;dbname=snappymail`
- User: `snappymail`
- Password: `Ch4ng3-7h1S-Pa5SW0rd`


## Migration from RainLoop

SnappyMail is a direct fork of RainLoop and reads the same configuration
and account storage format. Copy the old `/etc/rainloop` volume contents into
the new `/app/data` volume to carry over all settings.


## OpenPGP in the webmail (php-gnupg)

The php-fpm image ships the `php-gnupg` extension plus the `gpg`
binary it drives (gpgme execs gpg at runtime). SnappyMail's OpenPGP
features — verifying signed mail, signing and encrypting outgoing
mail with server-stored keys — work out of the box; enable them per
user under *Settings → OpenPGP*. Client-side OpenPGP.js is available
independently of this extension.

**Headless deviation — the extension is preferred over upstream's CLI
backend (`WORKAROUND` in `Dockerfile.php-fpm`):** SnappyMail's GnuPG
factory prefers its CLI backend, which spawns the `gpg` binary through
a string `proc_open()` — PHP runs those via `/bin/sh`, and the
hardened image deliberately ships no shell. Unpatched, the CLI backend
looks available (the `gpg` binary exists for gpgme) but every
operation fails, so server-side OpenPGP would be silently dead while
the shipped extension sits unused. On top of that, upstream
hard-disables its php-gnupg backend (over passphrase-handling issues
of pre-1.5 extension versions; this image pins 1.5.4, which has
loopback-pinentry support). The image therefore patches both at build
time: the php-gnupg extension (gpgme execs `gpg` directly, no shell
involved) is re-enabled and preferred, the CLI stays as fallback for
shell-ful setups. The whole user path — key import,
signing, encrypting, decrypting, verifying in the webmail — is pinned
by the mailservice end-to-end suite (`tests/e2e/test_openpgp.py`).
Remove the patch when upstream's CLI backend works without a shell or
the order becomes configurable (anchor-greps fail the build loudly on
any upstream change to the factory).


## Verifying the pinned SnappyMail signing key

Every SnappyMail release published on
[github.com/the-djmaze/snappymail](https://github.com/the-djmaze/snappymail/releases)
ships a detached OpenPGP signature (`snappymail-<version>.tar.gz.asc`).
BOTH images refuse to build a tarball that does not verify against the
pinned public key in `rainloop/snappymail-signing-key.asc` —
`Dockerfile.php-fpm` (the backend) and `Dockerfile.nginx` (the static
tree, i.e. all JavaScript the browser executes). Pinned by
`tests/build-verification.sh` (`npm test`).

The repository ships a **placeholder** file. Before the image builds
the first time, replace it with the real public key:

1. Download the SnappyMail release-signing key from
   [https://snappymail.eu/](https://snappymail.eu/) (the project
   website — GitHub's own «Verified» badge relies on a different key
   and does not cover release tarballs).

2. Import into a local keyring and read the fingerprint:

   ```bash
   gpg --import /path/to/downloaded-key.asc
   gpg --list-keys --with-fingerprint
   ```

3. Cross-check the fingerprint against the value published on the
   project website and on the maintainer's other public channels
   (Mastodon, GitHub profile, release notes). Only proceed if two
   independent sources match.

4. Export ASCII-armoured and commit:

   ```bash
   gpg --armor --export <fingerprint> > rainloop/snappymail-signing-key.asc
   git add rainloop/snappymail-signing-key.asc
   git commit -m "Pin SnappyMail signing key <fingerprint>"
   ```

5. Rebuild: `docker compose build snappymail`. The build stage prints
   `**** SnappyMail v<version> tarball: OpenPGP signature verified` on
   success and aborts on any mismatch.

Rotating the key later follows the same steps — a new commit replaces
the file. Downgrading the file back to the placeholder is a security
incident, because every subsequent build then imports whatever tarball
GitHub serves without verification.

The build accepts an optional `SKIP_GPG_VERIFY` build argument that
disables this check. It is empty by default (verification enforced) and
exists solely for automated test harnesses that build against the
placeholder key — never set it for a production image.
