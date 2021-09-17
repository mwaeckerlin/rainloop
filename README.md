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


### Database for Contacts

To connect to a database, just configure it in «Contacts» settings page. With the example `docker-compose.yml`, the configuration is:
  - Type: `MySQL`
  - Dsn: `mysql:host=mysql;port=3306;dbname=rainloop`
  - User: `rainloop`
  - Password: `Ch4ng3-7h1S-Pa5SW0rd`