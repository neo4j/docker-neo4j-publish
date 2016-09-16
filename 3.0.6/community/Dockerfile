FROM java:openjdk-8-jre

ENV NEO4J_SHA256 efeab41183e9e5fa94a2d396c65ea93a24e9f105cb3b5f0d0a8e42fb709f4660
ENV NEO4J_TARBALL neo4j-community-3.0.6-unix.tar.gz
ARG NEO4J_URI=http://dist.neo4j.org/neo4j-community-3.0.6-unix.tar.gz

COPY ./local-package/* /tmp/

RUN curl --fail --silent --show-error --location --remote-name ${NEO4J_URI} \
    && echo "${NEO4J_SHA256} ${NEO4J_TARBALL}" | sha256sum --check --quiet - \
    && tar --extract --file ${NEO4J_TARBALL} --directory /var/lib \
    && mv /var/lib/neo4j-* /var/lib/neo4j \
    && rm ${NEO4J_TARBALL}

WORKDIR /var/lib/neo4j

RUN mv data /data \
    && ln --symbolic /data

VOLUME /data

COPY docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 7474 7473 7687

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["neo4j"]
