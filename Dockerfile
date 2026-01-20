FROM alpine:latest

ARG TARGETARCH 

WORKDIR /app

RUN apk update && apk add --no-cache \
    tzdata iputils vnstat dos2unix \
    jq tar curl htop wget procps \
    iptables net-tools bind-tools \
    busybox-extras ca-certificates \
    ca-certificates-bundle bash \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /app/cgi-bin /root/.urnetwork

COPY version.txt entrypoint.sh start_stable.sh start_nightly.sh start_jwt.sh urnetwork_ipinfo.sh start_update.sh /app/
COPY stats /app/cgi-bin/

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
