# Docker image for Rainloop Community Edition

Best to use as frontend in https://github.com/mwaeckerlin/mailservice

It creates two images:
  1. an Nginx proxy that serves static pages and forwards PHP
  2. a PHP FPM container that handles PHP files

Check `docker-compose.yml` for a usage example.


## Local Testing

Just run

    docker-compose up


Then open the page in your browser: http://localhost:8080/


## Volumes

You must permanently store:
  - settings: `/etc/rainloop`
  - data: `/var/lib/rainloop`


## Configuration

Install according to [the documentation on the Rainloop page](https://www.rainloop.net/docs/configuration/)

Default user:
  - user:     `admin`
  - password: `12345`

**Imortant:** Do not forget to change the `admin` password!