FROM postgres:latest

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	wget \
	gnupg \
	dirmngr \
	ca-certificates \
	pigz \
	pbzip2 \
	xz-utils \
	lrzip \
	brotli \
	zstd \
	&& update-ca-certificates \
	&& wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /sbin/mc \
	&& chmod +x /sbin/mc \
	&& apt-get purge -y --auto-remove wget \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY entrypoint.sh .
ENTRYPOINT ["/entrypoint.sh"]
