FROM redhat/ubi8-minimal:latest
ENV JAVA_HOME=/opt/java/openjdk
COPY --from=eclipse-temurin:17 $JAVA_HOME $JAVA_HOME

# gather pre-requisite packages
RUN set -eux; \
    arch="$(uname -m)"; \
    case "${arch}" in \
        'x86_64') \
            tiniurl="https://github.com/krallin/tini/releases/download/v0.19.0/tini"; \
            gosuurl="https://github.com/tianon/gosu/releases/download/1.16/gosu-amd64"; \
            ;; \
        'aarch64') \
            tiniurl="https://github.com/krallin/tini/releases/download/v0.19.0/tini-arm64"; \
            gosuurl="https://github.com/tianon/gosu/releases/download/1.16/gosu-arm64"; \
            ;; \
        *) echo >&2 "Neo4j does not currently have a docker image for architecture $arch"; exit 1 ;; \
    esac; \
    microdnf install -y \
        findutils \
        gzip \
        hostname \
        jq \
        procps \
        shadow-utils \
        tar \
        wget \
        which; \
    wget -q ${tiniurl} -O /usr/bin/tini; \
    wget -q ${tiniurl}.asc -O tini.asc; \
    wget -q ${gosuurl} -O /usr/sbin/gosu; \
    wget -q  ${gosuurl}.asc -O gosu.asc; \
    chmod a+x /usr/bin/tini; \
    chmod a+x /usr/sbin/gosu; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys \
        595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
        B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify tini.asc /usr/bin/tini; \
    gpg --batch --verify gosu.asc /usr/sbin/gosu; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" tini.asc gosu.asc; \
    microdnf clean all

ENV PATH="${JAVA_HOME}/bin:${PATH}" \
    NEO4J_SHA256=3d387334532ff35c6114343fadea68657f0c600665daa5af75fce96c087c6ddc \
    NEO4J_TARBALL=neo4j-enterprise-5.10.0-unix.tar.gz \
    NEO4J_EDITION=enterprise \
    NEO4J_HOME="/var/lib/neo4j"
ARG NEO4J_URI=https://dist.neo4j.org/neo4j-enterprise-5.10.0-unix.tar.gz

COPY ./local-package/* /startup/

RUN set -eux; \
    groupadd --gid 7474 --system neo4j && useradd --uid 7474 --system --no-create-home --home "${NEO4J_HOME}" --gid neo4j neo4j; \
    curl --fail --silent --show-error --location --remote-name ${NEO4J_URI}; \
    echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -c --strict --quiet; \
    tar --extract --file ${NEO4J_TARBALL} --directory /var/lib; \
    mv /var/lib/neo4j-* "${NEO4J_HOME}"; \
    rm ${NEO4J_TARBALL}; \
    mv "${NEO4J_HOME}"/data /data; \
    mv "${NEO4J_HOME}"/logs /logs; \
    chown -R neo4j:neo4j /data; \
    chmod -R 777 /data; \
    chown -R neo4j:neo4j /logs; \
    chmod -R 777 /logs; \
    chown -R neo4j:neo4j "${NEO4J_HOME}"; \
    chmod -R 777 "${NEO4J_HOME}"; \
    ln -s /data "${NEO4J_HOME}"/data; \
    ln -s /logs "${NEO4J_HOME}"/logs; \
    mv /startup/neo4j-admin-report.sh "${NEO4J_HOME}"/bin/neo4j-admin-report

ENV PATH "${NEO4J_HOME}"/bin:$PATH

WORKDIR "${NEO4J_HOME}"

VOLUME /data /logs

EXPOSE 7474 7473 7687

ENTRYPOINT ["tini", "-g", "--", "/startup/docker-entrypoint.sh"]
CMD ["neo4j"]
