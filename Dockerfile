FROM alpine:latest

ARG TARGETARCH 

WORKDIR /app

RUN apk update && apk add --no-cache \
    tzdata iputils vnstat dos2unix \
    jq tar curl htop wget procps \
    iptables net-tools bind-tools \
    busybox-extras ca-certificates \
    ca-certificates-bundle bash \
    gosu \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /app/cgi-bin /root/.urnetwork

RUN addgroup -g 999 pelican \
    && adduser -D -u 999 -G pelican pelican \
    && echo "pelican:x:999:999:Pelican:/home/pelican:/bin/sh" >> /etc/passwd \
    && echo "pelican:x:999:" >> /etc/group \
    && mkdir -p /home/pelican \
    && chown -R root:pelican /app /root/.urnetwork \
    && chmod -R 775 /app /root/.urnetwork

COPY scripts/*.sh /app/
COPY scripts/stats /app/cgi-bin/

RUN dos2unix /app/*.sh /app/cgi-bin/stats && chmod +x /app/*.sh /app/cgi-bin/stats

RUN sed -i \
  -e 's/^;*TimeSyncWait.*/TimeSyncWait 1/' \
  -e 's/^;*TrafficlessEntries.*/TrafficlessEntries 1/' \
  -e 's/^;*UpdateInterval.*/UpdateInterval 15/' \
  -e 's/^;*PollInterval.*/PollInterval 15/' \
  -e 's/^;*SaveInterval.*/SaveInterval 1/' \
  -e 's/^;*UnitMode.*/UnitMode 1/' \
  -e 's/^;*RateUnit.*/RateUnit 0/' \
  -e 's/^;*RateUnitMode.*/RateUnitMode 0/' \
  /etc/vnstat.conf

RUN /app/start_update.sh

VOLUME ["/root/.urnetwork"]

ENTRYPOINT ["/app/entrypoint.sh"]
