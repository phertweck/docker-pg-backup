##############################################################################
# Production Stage                                                           #
##############################################################################
ARG POSTGRES_MAJOR_VERSION=14
ARG POSTGIS_MAJOR_VERSION=3
ARG POSTGIS_MINOR_RELEASE=1

FROM kartoza/postgis:$POSTGRES_MAJOR_VERSION-$POSTGIS_MAJOR_VERSION.${POSTGIS_MINOR_RELEASE} AS postgis-backup-production

RUN apt-get -y update; apt-get -y --no-install-recommends install  cron python3-pip vim  gettext \
    && apt-get -y --purge autoremove && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install s3cmd

RUN addgroup --system --gid 1000 pg-backup \
    && adduser --system --uid 1000 --gid 1000 pg-backup

RUN touch /var/log/cron.log

ENV \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ADD build_data /build_data
ADD scripts /backup-scripts
RUN mkdir /settings \
    && chown -R pg-backup:pg-backup /settings \
    && chown -R pg-backup:pg-backup /backup-scripts \
    && touch /var/run/crond.pid \
    && chgrp pg-backup /var/run/crond.pid \
    && chmod 0755 /backup-scripts/*.sh \
    && chgrp -R 0 /backup-scripts \
    && chmod -R g=u /backup-scripts \
    && echo 'pg-backup' > /etc/cron.allow
RUN sed -i 's/PostGIS/PgBackup/' ~/.bashrc

WORKDIR /backup-scripts

USER pg-backup
ENTRYPOINT ["/bin/bash", "/backup-scripts/start.sh"]
CMD ["/scripts/docker-entrypoint.sh"]


##############################################################################
# Testing Stage                                                           #
##############################################################################
FROM postgis-backup-production AS postgis-backup-test

COPY scenario_tests/utils/requirements.txt /lib/utils/requirements.txt

USER root

RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y --no-install-recommends install python3-pip \
    && apt-get -y --purge autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install -r /lib/utils/requirements.txt
