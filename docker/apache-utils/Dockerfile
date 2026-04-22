# 轻量 apache2-utils（htpasswd、htdigest 等），替代已不可用的 apache/apache-utils
FROM alpine:3.20

RUN apk add --no-cache apache2-utils \
    && rm -rf /var/cache/apk/*

# 用法: docker run --rm -v ... IMAGE htpasswd -cb /path/to/file user password
CMD ["htpasswd", "-h"]
