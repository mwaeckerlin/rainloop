# Changelog

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
