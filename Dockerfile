FROM debian:latest

ENV SEAFILE_VERSION="5.1.2" \
    SEAFILE_INSTALLDIR="/opt/seafile" \
    SEAFILE_SERVERINSTALLDIR="/opt/seafile/seafile-server" \
    SEAFILE_CONFDIR="/opt/seafile/conf" \
    SEAFILE_CCNET_CONFDIR="/opt/seafile/ccnet" \
    SEAFILE_DATADIR="/opt/seafile/seafile-data" \
    SEAFILE_SEAHUB_DATADIR="/opt/seafile/seahub-data" \
    SUPERVISORD_CONFDIR="/etc/supervisor/conf.d"

RUN useradd -r seafile \
 && ulimit -n 30000

RUN apt-get update \
 && apt-get install -y python2.7 libpython2.7 python-setuptools python-imaging python-ldap sqlite3 curl supervisor \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p ${SEAFILE_SERVERINSTALLDIR} \
 && curl -Lk http://bintray.com/artifact/download/seafile-org/seafile/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz | tar xzf - --strip-components=1 -C ${SEAFILE_SERVERINSTALLDIR} \
 && ${SEAFILE_SERVERINSTALLDIR}/setup-seafile.sh auto \
 && chown -R seafile ${SEAFILE_SERVERINSTALLDIR}

# https://github.com/Yelp/dumb-init
RUN curl -fLsS -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.0.2/dumb-init_1.0.2_amd64 && chmod +x /usr/local/bin/dumb-init

RUN apt-get remove -qq curl

RUN mkdir -p ${SUPERVISORD_CONFDIR}
COPY supervisord-config/* ${SUPERVISORD_CONFDIR}/
RUN chmod +x ${SUPERVISORD_CONFDIR}/shutdownhandler.sh

COPY seafile_entrypoint.sh /
RUN chmod +x seafile_entrypoint.sh
ENTRYPOINT ["/usr/local/bin/dumb-init", "/seafile_entrypoint.sh"]

VOLUME ${SEAFILE_CONFDIR} ${SEAFILE_DATADIR} ${SEAFILE_SEAHUB_DATADIR}
EXPOSE 8000 8082
