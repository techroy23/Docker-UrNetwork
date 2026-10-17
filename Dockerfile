FROM alpine:latest

ARG TARGETARCH 

WORKDIR /app

RUN apk update && apk add --no-cache \
    tzdata iputils dos2unix \
    jq tar curl htop wget procps \
    iptables net-tools bind-tools \
    ca-certificates ca-certificates-bundle bash \
    gosu \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /root/.urnetwork

COPY scripts/*.sh /app/

RUN dos2unix /app/*.sh && chmod +x /app/*.sh

RUN /app/start_update.sh

VOLUME ["/root/.urnetwork"]

EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
