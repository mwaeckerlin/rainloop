# Tests

Register of all tests of the version line 1, grouped by kind and sorted by the [FEATURES.md](FEATURES.md) number each test covers. `npm test` runs everything: the docs contract, the compose contract, the build of both images, the config contract and the end-to-end test. The guard `tests/docs-contract.sh` fails when a feature has no test entry here, when a number here names no feature, or when a script in `tests/` is called by no script of `package.json`.

## End-to-end

`tests/e2e.sh` starts both built images in a network of their own, the php-fpm image under its service name `snappymail` on a fresh data volume, and requests the webmail through nginx with the PHP of the php-fpm image.

- **F1** `tests/e2e.sh` › start_page_rendered_by_php — the start page answers 200 with HTML that PHP rendered, no PHP source.
- **F1** `tests/e2e.sh` › static_file_of_the_release_served — the stylesheet `app.min.css` of the release that the start page links answers 200 from nginx with the file, no HTML page.
- **F1** `tests/e2e.sh` › admin_page_rendered_by_php — `/?admin` answers 200 with HTML.
- **F1** `tests/e2e.sh` › admin_data_answered_without_login — `/?/AdminAppData/0/1/`, the data the admin page loads, answers 200 with JSON that reports no login (`"Auth":false`).
- **F2** `tests/e2e.sh` › configuration_written_to_the_volume — after the first request, a new php-fpm container on the same volume finds `_data_/_default_/configs/application.ini`.
- **F1, F2** `tests/e2e.sh` › admin_password_generated_in_the_volume — after the admin page loaded its data, the data volume holds `_data_/_default_/admin_password.txt` with a password of at least 8 characters.

## Image contract

- **F2** `tests/config-contract.sh` › volume__app_data — the php-fpm image declares `/app/data` as a volume.
- **F3** `tests/config-contract.sh` › php_patched_release, selftest_patched_release_limits — the PHP of the image is at least 8.5.12 or 8.4.27; the comparison accepts 8.5.12, 8.4.27, 8.6.0 and 9.0.0 and refuses 8.5.11, 8.4.26, 8.4.21, 8.3.99 and a line without a version.
- **F3** `tests/config-contract.sh` › session_upload_progress_off, session_upload_progress_locked, fatal_error_backtraces_locked — `php-fpm -i` reports `session.upload_progress.enabled` Off, and `php-fpm -tt` shows the pool locking it and `fatal_error_backtraces` off.

## Compose contract

- **F1** `tests/compose-contract.sh` › php_fpm_host_is_the_php_service — `PHP_FPM_HOST` of `Dockerfile.nginx` is the name of the compose service of the php-fpm image.
- **F2** `tests/compose-contract.sh` › data_volume_on_app_data — the compose example mounts the named volume `data` on `/app/data`.
- **F4** `tests/compose-contract.sh` › docker-compose_renders, published_names_of_branch_1 — with the selection and the tag rule of the shared workflow of `mwaeckerlin/scratch` and the `branch-tags` of `.github/workflows/docker.yml`, the branch `1` publishes exactly `mwaeckerlin/rainloop:php-fpm` and `php-fpm-1` from the stage `php-fpm` of `Dockerfile.php-fpm`, and `nginx` and `nginx-1` from the stage `nginx` of `Dockerfile.nginx`, and `npm run deploy` pushes all four.
- **F5** `tests/compose-contract.sh` › published_address_from_bind_address, docker-compose_renders_without_warning — `docker compose config` renders without a warning, with no host address while `BIND_ADDRESS` is unset or empty and with `192.0.2.10` on every published port when it is set.
