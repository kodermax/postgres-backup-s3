FROM postgres:18

# MC_VERSION can be overridden at build time: --build-arg MC_VERSION=RELEASE.2024-01-01T00-00-00Z
ARG MC_VERSION=latest

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
	&& MC_URL="https://dl.min.io/client/mc/release/linux-amd64/mc" \
	&& if [ "$MC_VERSION" != "latest" ]; then MC_URL="https://dl.min.io/client/mc/release/linux-amd64/archive/mc.${MC_VERSION}"; fi \
	&& wget -q "${MC_URL}.sha256sum" -O /tmp/mc.sha256sum \
	&& MC_FILENAME=$(awk '{print $2}' /tmp/mc.sha256sum) \
	&& wget -q "${MC_URL}" -O "/tmp/${MC_FILENAME}" \
	&& cd /tmp && sha256sum -c mc.sha256sum \
	&& mv "/tmp/${MC_FILENAME}" /sbin/mc \
	&& chmod +x /sbin/mc \
	&& apt-get purge -y --auto-remove wget \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV MC_CONFIG_DIR=/tmp/mc-config

COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
