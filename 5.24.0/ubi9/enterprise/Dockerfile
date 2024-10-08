FROM redhat/ubi9-minimal:latest

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
    openssl_url="https://www.openssl.org/source/openssl-3.0.9.tar.gz"; \
    openssl_sha="eb1ab04781474360f77c318ab89d8c5a03abc38e63d65a603cabbf1b00a1dc90"; \
    microdnf install -y --nodocs \
        apr \
        crypto-policies-scripts \
        findutils \
        gcc \
        git \
        gzip \
        hostname \
        java-17-openjdk-headless \
        jq \
        make \
        perl-Digest-SHA \
        perl-File-Compare \
        perl-File-Copy \
        perl-FindBin \
        perl-IPC-Cmd \
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
    wget -q ${openssl_url} -O /openssl.tar.gz; \
    wget -q ${openssl_url}.asc -O /openssl.tar.gz.asc; \
    # verify tini and openssl shasum and gpg signatures
    echo ${openssl_sha} /openssl.tar.gz  | sha256sum -c; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys \
        6380DC428747F6C393FEACA59A84159D7001A4E5 \
        A21FAB74B0088AA361152586B8EF1A6BA9DA2D5C; \
    gpg --batch --verify tini.asc /usr/bin/tini; \
    gpg --batch --verify /openssl.tar.gz.asc /openssl.tar.gz; \
    # install openssl
    tar -xzf /openssl.tar.gz --directory /tmp; \
    cd /tmp/openssl-3.0.9; \
    ./Configure --prefix=/usr/local/openssl --openssldir=/usr/local/openssl enable-fips no-tests no-legacy shared; \
    make install_sw install_ssldirs install_fips; \
    if [ ${arch} = "aarch64" ]; \
      then ldconfig /usr/local/openssl/lib; \
      else ldconfig /usr/local/openssl/lib64; \
    fi; \
    cd /; \
    # download, verify and install su-exec
    git clone https://github.com/ncopa/su-exec.git; \
    cd su-exec; \
    git checkout 4c3bb42b093f14da70d8ab924b487ccfbb1397af; \
    echo d6c40440609a23483f12eb6295b5191e94baf08298a856bab6e15b10c3b82891 su-exec.c | sha256sum -c; \
    echo 2a87af245eb125aca9305a0b1025525ac80825590800f047419dc57bba36b334 Makefile | sha256sum -c; \
    make; \
    mv /su-exec/su-exec /usr/bin/su-exec; \
    # clean up build files and downloads
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME" /tini.asc /su-exec /openssl.tar.gz /openssl.tar.gz.asc /tmp/openssl*; \
    microdnf remove -y git* perl* make gcc glibc-headers glibc-devel libxcrypt-devel; \
    microdnf clean all

ENV NEO4J_SHA256=ff359910560e706f38ef5c7a25fec0e0e0d0be21abbb2a845dff48e8b702d3b8 \
    NEO4J_TARBALL=neo4j-enterprise-5.24.0-unix.tar.gz \
    NEO4J_EDITION=enterprise \
    NEO4J_HOME="/var/lib/neo4j" \
    LANG=C.UTF-8
ARG NEO4J_URI=https://dist.neo4j.org/neo4j-enterprise-5.24.0-unix.tar.gz

COPY ./local-package/* /startup/

RUN set -eux; \
    groupadd --gid 7474 --system neo4j && useradd --uid 7474 --system --no-create-home --home "${NEO4J_HOME}" --gid neo4j neo4j; \
    curl --fail --silent --show-error --location --remote-name ${NEO4J_URI}; \
    echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -c --strict --quiet; \
    tar --extract --file ${NEO4J_TARBALL} --directory /var/lib; \
    mv /var/lib/neo4j-* "${NEO4J_HOME}"; \
    rm ${NEO4J_TARBALL}; \
    sed -i 's/Package Type:.*/Package Type: docker ubi9/' $NEO4J_HOME/packaging_info; \
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
    ln -s /logs "${NEO4J_HOME}"/logs

ENV PATH="${NEO4J_HOME}/bin:/usr/local/openssl/bin:$PATH"
WORKDIR "${NEO4J_HOME}"

VOLUME /data /logs

EXPOSE 7474 7473 7687

ENTRYPOINT ["tini", "-g", "--", "/startup/docker-entrypoint.sh"]
CMD ["neo4j"]
