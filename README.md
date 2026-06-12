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
