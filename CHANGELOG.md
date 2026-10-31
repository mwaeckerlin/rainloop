# Changelog

- 2026-10-31 **1.11.3**
    - `mwaeckerlin/rainloop:php-fpm` and `mwaeckerlin/rainloop:nginx` are built again, from this version line, on every push and in the hourly check; until now they served the images of 2026-07-16 and 2026-07-18, the php-fpm image with PHP 8.4.21, which is open to CVE-2026-109618 and CVE-2026-109619. The names `php-fpm-1` and `nginx-1` stay, for the same images
    - A test refuses a PHP older than 8.5.12 on the line 8.5 and older than 8.4.27 on the line 8.4, the first releases with the fix of both CVEs, and checks that the pool also locks fatal error backtraces off
    - The compose example keeps configuration and accounts: it mounted the data volume on `/app/snappymail/data`, a path SnappyMail never writes, while the image keeps its data in `/app/data`. A stack started from the old example has its data in the unnamed volume of the container; copy it into the volume `data` before the next start
    - `BIND_ADDRESS` limits the published port 8080 of the compose example to one address of the host; unset, it stays on every address
    - An end-to-end test runs both images together and requests the webmail and the admin panel through nginx

- 2026-10-24 **1.11.2**
    - The build takes the newest SnappyMail release whose tarball can be downloaded: v2.38.2.1 was published without any file, `releases/latest` pointed at it and every build failed with 404; a release whose files are still missing is skipped until they are there
    - The nginx image builds without a warning of the Docker build checks

- 2026-10-21 **1.11.1**
    - The version line 1 is built and published again, as `mwaeckerlin/rainloop:php-fpm-1` and `nginx-1`, on every push to this branch and with the weekly run on master. Until then it got no rebuild and so no security fix of its base image, the latest being the mitigations against CVE-2026-109618 and CVE-2026-109619 of `mwaeckerlin/php-fpm`; a test checks that they work in the image

- 2026-09-09 **1.11.0**
    - The images build again on the base image with PHP 8.5: the PHP version is no longer written into the build, and the nginx stage carries the name the compose file asks for

- 2026-06-12 **1.10.0**
    - PHP error output is off in the FPM pool, so deprecation warnings no longer break the JSON interface of the admin panel and no longer prevent the login
    - Environment variables are passed on to the FPM worker
    - The data volume is declared on the path SnappyMail writes, so configuration and accounts are kept
