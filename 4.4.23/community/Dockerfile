FROM debian:bullseye-slim
ENV JAVA_HOME=/opt/java/openjdk
COPY --from=eclipse-temurin:11 $JAVA_HOME $JAVA_HOME
ENV PATH="${JAVA_HOME}/bin:${PATH}" \
    NEO4J_SHA256=85a7dfd2b7fa039b81f445cd945515c95b68ff40cf910701d38f81cd9f07b4dc \
    NEO4J_TARBALL=neo4j-community-4.4.23-unix.tar.gz \
    NEO4J_EDITION=community \
    NEO4J_HOME="/var/lib/neo4j"
ARG NEO4J_URI=https://dist.neo4j.org/neo4j-community-4.4.23-unix.tar.gz

RUN addgroup --gid 7474 --system neo4j && adduser --uid 7474 --system --no-create-home --home "${NEO4J_HOME}" --ingroup neo4j neo4j

COPY ./local-package/* /startup/

RUN apt update \
    && apt install -y curl gosu jq procps tini wget \
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
    && ln -s /logs "${NEO4J_HOME}"/logs \
    && ln -s /startup/docker-entrypoint.sh /docker-entrypoint.sh \
    && mv /startup/neo4j-admin-report.sh "${NEO4J_HOME}"/bin/neo4j-admin-report \
    && apt-get -y purge --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*


ENV PATH "${NEO4J_HOME}"/bin:$PATH

WORKDIR "${NEO4J_HOME}"

VOLUME /data /logs

EXPOSE 7474 7473 7687

ENTRYPOINT ["tini", "-g", "--", "/startup/docker-entrypoint.sh"]
CMD ["neo4j"]
