FROM openjdk:8-jre-slim

ENV NEO4J_SHA256=f536224565ce27b95947c91a37d52b9ba9e80247d8d3262075b24b8d47f8532a \
    NEO4J_TARBALL=neo4j-community-3.5.6-unix.tar.gz \
    NEO4J_EDITION=community \
    NEO4J_HOME="/var/lib/neo4j" \
    TINI_VERSION="v0.18.0" \
    TINI_SHA256="12d20136605531b09a2c2dac02ccee85e1b874eb322ef6baf7561cd93f93c855"
ARG NEO4J_URI=http://dist.neo4j.org/neo4j-community-3.5.6-unix.tar.gz

RUN addgroup --system neo4j && adduser --system --no-create-home --home "${NEO4J_HOME}" --ingroup neo4j neo4j

COPY ./local-package/* /tmp/

RUN apt update \
    && apt install -y curl gosu \
    && curl -L --fail --silent --show-error "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini" > /sbin/tini \
    && echo "${TINI_SHA256}  /sbin/tini" | sha256sum -c --strict --quiet \
    && chmod +x /sbin/tini \
    && curl --fail --silent --show-error --location --remote-name ${NEO4J_URI} \
    && echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -c --strict --quiet \
    && tar --extract --file ${NEO4J_TARBALL} --directory /var/lib \
    && mv /var/lib/neo4j-* "${NEO4J_HOME}" \
    && rm ${NEO4J_TARBALL} \
    && mv "${NEO4J_HOME}"/data /data \
    && mv "${NEO4J_HOME}"/logs /logs \
    && chown -R neo4j:neo4j /data \
    && chmod -R 777 /data \
    && chown -R neo4j:neo4j /logs \
    && chmod -R 777 /logs \
    && chown -R neo4j:neo4j "${NEO4J_HOME}" \
    && chmod -R 777 "${NEO4J_HOME}" \
    && ln -s /data "${NEO4J_HOME}"/data \
    && ln -s /logs "${NEO4J_HOME}"/logs

ENV PATH "${NEO4J_HOME}"/bin:$PATH

WORKDIR "${NEO4J_HOME}"

VOLUME /data /logs

COPY docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 7474 7473 7687

ENTRYPOINT ["/sbin/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["neo4j"]
