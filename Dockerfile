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

# The container runs entirely as this unprivileged user. Its state lives in
# its own home directory, not in /root.
RUN addgroup -g 1000 urnetwork \
 && adduser -D -u 1000 -G urnetwork -h /home/urnetwork -s /sbin/nologin urnetwork

RUN mkdir -p /home/urnetwork/.urnetwork \
 && chown -R urnetwork:urnetwork /home/urnetwork \
 && chmod 700 /home/urnetwork /home/urnetwork/.urnetwork

COPY scripts/*.sh /app/

RUN dos2unix /app/*.sh && chmod +x /app/*.sh

RUN /app/start_update.sh

# The provider replaces its own binary in /app during daily updates, so the
# runtime user owns that directory too.
RUN chown -R urnetwork:urnetwork /app

ENV HOME=/home/urnetwork
USER urnetwork

VOLUME ["/home/urnetwork/.urnetwork"]

EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
