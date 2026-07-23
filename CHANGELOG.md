# Changelog

- 2026-07-20 **server-side OpenPGP fixed in the headless image**
    - Server-side OpenPGP actually works now. SnappyMail prefers its
      CLI GnuPG backend, which needs a shell the hardened image
      deliberately does not ship — every key operation failed silently
      while the bundled php-gnupg extension sat unused (upstream even
      hard-disables it over passphrase issues of pre-1.5 extension
      versions; this image pins 1.5.4). The image now re-enables the
      extension backend and prefers it at build time; the whole
      webmail flow — import,
      sign, encrypt, decrypt, verify — is pinned by the mailservice
      end-to-end suite. This also removes the shell-related PHP
      warnings and lingering per-user gpg-agent processes of the CLI
      attempts.

- 2026-07-20 **transport-security plugin**
    - Ships a SnappyMail plugin that marks how securely each incoming
      mail was transported: it reads the `X-Transport-Security` header
      (stamped by the mailservice MX) for the opened message and shows a
      red «UNENCRYPTED» banner for a cleartext hop, orange for an
      obsolete TLS version, and nothing for TLS 1.2+. The plugin is
      bundled in the image and installed into the data volume + enabled
      by an init container (`Dockerfile.plugin-init` / `install-plugins.sh`).
      Pinned by e2e tests (`test_webui.py`): the red banner appears for a
      plaintext-delivered mail and is absent for a TLS-submitted one.

- 2026-07-18 **security hardening**
    - Release-signature verification now covers BOTH images: the nginx
      image serves the complete static tree — all JavaScript the
      browser executes — and previously downloaded the tarball without
      any check. Both builds now verify the OpenPGP signature against
      the pinned key and refuse the placeholder without the documented
      test escape hatch. Pinned by the new build-verification test
      suite (`npm test`).
    - The release-tag discovery aborts the build on an HTTP error or
      an empty tag instead of downloading from a half-built URL.
    - The standalone compose example persisted the data volume at the
      wrong path (`/app/snappymail/data` instead of `/app/data`) —
      configuration and accounts were lost on recreate; corrected.
    - `npm start` / `npm test` work as documented (the package
      scripts were missing).

- 2026-07-18 **build escape hatch**
    - The build now accepts an optional `SKIP_GPG_VERIFY` build
      argument. It is empty by default, so release-signature
      verification stays fully enforced; only automated test harnesses
      set it to bypass the check when they ship a placeholder signing
      key.

- 2026-07-17 **OpenPGP**
    - New: OpenPGP in webmail — the php-gnupg extension together with
      the gpg program is included in the image; verifying signed mail,
      signing/encrypting your own mail now works out of the box
      without any extra installation.
    - New: verification of the OpenPGP signature of the downloaded
      SnappyMail release tarball during the Docker build. The public
      key is pinned in the repo as `snappymail-signing-key.asc`; the
      build aborts as soon as either of the two checks fails
      (placeholder still active, gpg import broken, signature does not
      match the tarball).
    - README explains how to fetch the real key, verify it against the
      project fingerprint and commit it — including rotation and a
      note that reverting to the placeholder is a security incident.

- 2026-06-12 **fixes**
    - PHP error output disabled in the FPM pool, so deprecation
      warnings no longer corrupt the JSON interface of the
      administration area and no longer prevent login.
    - Environment variables are passed through to the FPM worker.
    - Data directory volume corrected to the proper path, so
      configuration and accounts are retained permanently.
