FROM redhat/ubi9-minimal:latest
ENV JAVA_HOME=/usr

# gather pre-requisite packages
RUN set -eux; \
    arch="$(rpm --query --queryformat='%{ARCH}' rpm)"; \
    case "${arch}" in \
        'x86_64') \
            tini_url="https://github.com/krallin/tini/releases/download/v0.19.0/tini"; \
            tini_sha="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c"; \
            ;; \
        'aarch64') \
            tini_url="https://github.com/krallin/tini/releases/download/v0.19.0/tini-arm64"; \
            tini_sha="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81"; \
            ;; \
        *) echo >&2 "Neo4j does not currently have a docker image for architecture $arch"; exit 1 ;; \
    esac; \
    microdnf install -y dnf; \
    dnf install -y \
        findutils \
        gcc \
        git \
        gzip \
        hostname \
        java-11-openjdk-headless \
        jq \
        make \
        procps \
        shadow-utils \
        tar \
        wget \
        which; \
    # download tini and openssl
    wget -q ${tini_url} -O /usr/bin/tini; \
    wget -q ${tini_url}.asc -O tini.asc; \
    echo "${tini_sha}"  /usr/bin/tini | sha256sum -c --strict --quiet; \
    chmod a+x /usr/bin/tini; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys \
        595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
        B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify tini.asc /usr/bin/tini; \
    git clone https://github.com/ncopa/su-exec.git; \
    cd su-exec; \
    git checkout 4c3bb42b093f14da70d8ab924b487ccfbb1397af; \
    echo d6c40440609a23483f12eb6295b5191e94baf08298a856bab6e15b10c3b82891 su-exec.c | sha256sum -c; \
    echo 2a87af245eb125aca9305a0b1025525ac80825590800f047419dc57bba36b334 Makefile | sha256sum -c; \
    make; \
    mv /su-exec/su-exec /usr/bin/su-exec; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" tini.asc /su-exec; \
    dnf remove -y gcc git make; \
    dnf autoremove; \
    dnf clean all

ENV PATH="${JAVA_HOME}/bin:${PATH}" \
    NEO4J_SHA256=452bad595302f9c8bf56f311b5076ef21e98e270229403dca90b2d61b2297b33 \
    NEO4J_TARBALL=neo4j-community-4.4.38-unix.tar.gz \
    NEO4J_EDITION=community \
    NEO4J_HOME="/var/lib/neo4j" \
    LANG=C.UTF-8
ARG NEO4J_URI=https://dist.neo4j.org/neo4j-community-4.4.38-unix.tar.gz

COPY ./local-package/* /startup/

RUN set -eux; \
    groupadd --gid 7474 --system neo4j && useradd --uid 7474 --system --no-create-home --home "${NEO4J_HOME}" --gid neo4j neo4j; \
    curl --fail --silent --show-error --location --remote-name ${NEO4J_URI}; \
    echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -c --strict --quiet; \
    tar --extract --file ${NEO4J_TARBALL} --directory /var/lib; \
    mv /var/lib/neo4j-* "${NEO4J_HOME}"; \
    rm ${NEO4J_TARBALL}; \
    mv /startup/neo4j-admin-report.sh "${NEO4J_HOME}"/bin/neo4j-admin-report; \
    mv "${NEO4J_HOME}"/data /data; \
    mv "${NEO4J_HOME}"/logs /logs; \
    chown -R neo4j:neo4j /data; \
    chmod -R 777 /data; \
    chown -R neo4j:neo4j /logs; \
    chmod -R 777 /logs; \
    chown -R neo4j:neo4j "${NEO4J_HOME}"; \
    chmod -R 777 "${NEO4J_HOME}"; \
    chmod -R 755 "${NEO4J_HOME}/bin"; \
    ln -s /data "${NEO4J_HOME}"/data; \
    ln -s /logs "${NEO4J_HOME}"/logs; \
    ln -s /startup/docker-entrypoint.sh /docker-entrypoint.sh

ENV PATH="${NEO4J_HOME}"/bin:$PATH

WORKDIR "${NEO4J_HOME}"

VOLUME /data /logs

EXPOSE 7474 7473 7687

ENTRYPOINT ["tini", "-g", "--", "/startup/docker-entrypoint.sh"]
CMD ["neo4j"]
