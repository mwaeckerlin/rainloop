# Docker image for SnappyMail, version line 1

SnappyMail is an actively maintained fork of RainLoop. This image replaces the abandoned RainLoop Community Edition with a drop-in equivalent that supports PHP 8.

Best used as webmail frontend in https://github.com/mwaeckerlin/mailservice

The branch `1` of this repository is the version line 1. It carries the SnappyMail image that `mwaeckerlin/rainloop:php-fpm` and `mwaeckerlin/rainloop:nginx` served on 2026-07-16, without the OpenPGP support, the transport-security plugin and the configuration from the environment that the branch `master` adds; `master` is published as `mwaeckerlin/snappymail`. The line is rebuilt when one of its base images changes, and at least once a week.

The features are listed in [FEATURES.md](FEATURES.md), the tests that cover them in [TESTS.md](TESTS.md), the changes in [CHANGELOG.md](CHANGELOG.md).


## Images

The repository builds an nginx image and a php-fpm image, for amd64 and arm64:

1. `mwaeckerlin/rainloop:nginx` — nginx serving the static files of SnappyMail and forwarding every PHP request to the host `snappymail`, port 9000
2. `mwaeckerlin/rainloop:php-fpm` — PHP-FPM running SnappyMail, port 9000

Both are also published as `nginx-1` and `php-fpm-1`, and every name also with the day of the build, the version and both together, for example `php-fpm-20261031`, `php-fpm-1.11.3` and `php-fpm-1.11.3-20261031`. The image a build replaces stays available under its name and the day it was built, for example `php-fpm-20260716`.

The image is built from the newest SnappyMail release whose download tarball exists; a release published before its files is skipped until they are there.

Check `docker-compose.yml` for a usage example.


## Upgrade from the image of 2026-07-16

`mwaeckerlin/rainloop:php-fpm` of 2026-07-16 runs PHP 8.4.21, which is open to CVE-2026-109618 and CVE-2026-109619, and `mwaeckerlin/rainloop:nginx` was last built on 2026-07-18. A `docker pull` of the same names gets the current build of this line. SnappyMail stays in `/app` and its data in the volume `/app/data`, the php-fpm image listens on port 9000, the nginx image on port 8080 and forwards PHP to the host `snappymail`. PHP becomes the release of `mwaeckerlin/php-fpm`, at least 8.5.12 or 8.4.27, with session upload progress and fatal error backtraces locked off, and SnappyMail the newest release.

The compose example of this branch mounted its named volume `data` on `/app/snappymail/data`, a path SnappyMail never writes, so a stack started from it kept its data in the unnamed volume Docker creates for `/app/data`. The example now mounts `data` on `/app/data`. Before such a stack is started with the new example, copy the unnamed volume into `data`, with the names `docker volume ls` shows:

```bash
docker run --rm -v <unnamed volume>:/from:ro -v <project>_data:/to alpine cp -a /from/. /to/
```


## Local Testing

```bash
npm start
```

Then open: http://localhost:8080/


## Volumes

Store permanently:
- `data`: `/app/data` — all configuration, accounts, cached state


## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BIND_ADDRESS` | — (every address) | Host address the compose example publishes port 8080 on, for example `127.0.0.1` for the own machine only. |
| `PHP_FPM_HOST` | `snappymail` | Host of the php-fpm container, in the nginx image. |
| `PHP_FPM_PORT` | `9000` | Port of the php-fpm container, in the nginx image. |

Open the admin panel at http://localhost:8080/?admin with the user `admin`. On the first visit, SnappyMail writes a generated password into `_data_/_default_/admin_password.txt` in the data volume.


### IMAP / SMTP Server

In the admin panel → *Domains* → *Add domain*:
- IMAP host: your dovecot hostname, port 143 (or 993 for TLS)
- SMTP host: your postfix hostname, port 25 (or 587 for submission)


### Database for Contacts

Admin panel → *Contacts* → configure:
- Type: `MySQL`
- DSN: `mysql:host=mysql;port=3306;dbname=snappymail`
- User: `snappymail`
- Password: `Ch4ng3-7h1S-Pa5SW0rd`


## Migration from RainLoop

SnappyMail is a direct fork of RainLoop and reads the same configuration and account storage format. Copy the old `/etc/rainloop` volume contents into the new `/app/data` volume to carry over all settings.


## Development

| Script | What it does |
| --- | --- |
| `npm run build` | `docker compose build`: both images under all four names |
| `npm start` | the example stack in the foreground |
| `npm test` | the docs contract, the compose contract, the build, the config contract of the php-fpm image and the end-to-end test of both images |
| `npm run deploy` | pushes all four names; the workflow `.github/workflows/docker.yml` does it on every push to the branch `1` |

The workflow calls the reusable workflow `docker-image.yml` of `mwaeckerlin/scratch`, which publishes every compose service that has `build` and `image`. The `branch-tags` rule of this branch appends no suffix, so each image is published under the name the compose file gives it; the services `snappymail-1` and `snappymail-proxy-1` with `scale: 0` add the names `php-fpm-1` and `nginx-1`. The scheduled run of `master` starts this branch every hour, and the run builds when a parent image or a download changed or the published image is a week old.
