FROM mwaeckerlin/very-base as build
RUN $PKG_INSTALL rainloop-webmail
RUN mv /usr/share/webapps/rainloop /app
RUN $ALLOW_USER /var/lib/rainloop /etc/rainloop
RUN tar cp \
    /etc/ssl/certs /etc/php* /etc/rainloop \
    /usr/lib/php*/modules \
    /app \
    /var/lib/rainloop \
    | tar xpC /root/
RUN tar cp \
    $(for f in $(find /root -type f -executable) ; do \
    ldd $f | sed -n 's,.* => \([^ ]*\) .*,\1,p'; \
    done 2> /dev/null) 2> /dev/null \
    | tar xpC /root/
RUN tar cp \
    $(find /root -type l ! -exec test -e {} \; -exec echo -n "{} " \; -exec readlink {} \; | sed 's,/root\(.*\)/[^/]* \(.*\),\1/\2,') 2> /dev/null \
    | tar xpC /root/

FROM mwaeckerlin/nginx as nginx-config-prepare
FROM mwaeckerlin/very-base as nginx-config
COPY --from=nginx-config-prepare /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
RUN sed -i 's/ php-fpm;/ rainloop;/' /etc/nginx/conf.d/default.conf

FROM mwaeckerlin/nginx as nginx
COPY --from=build /root/app /app
COPY --from=nginx-config /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf

FROM mwaeckerlin/php-fpm as prepare-php
FROM prepare-php as php-fpm
COPY --from=build /root/ /
COPY --from=prepare-php /etc/php7/php.ini /etc/php7/php.ini