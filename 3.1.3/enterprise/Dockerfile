FROM openjdk:8-jre-alpine

RUN apk add --no-cache --quiet \
    bash \
    curl

ENV NEO4J_SHA256 b784a61228bdc31cbc843009e4d36d3e2aee7662f8b40bd608b8759de26b77d5
ENV NEO4J_TARBALL neo4j-enterprise-3.1.3-unix.tar.gz
ARG NEO4J_URI=http://dist.neo4j.org/neo4j-enterprise-3.1.3-unix.tar.gz

COPY ./local-package/* /tmp/

RUN curl --fail --silent --show-error --location --remote-name ${NEO4J_URI} \
    && echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -csw - \
    && tar --extract --file ${NEO4J_TARBALL} --directory /var/lib \
    && mv /var/lib/neo4j-* /var/lib/neo4j \
    && rm ${NEO4J_TARBALL}

WORKDIR /var/lib/neo4j

RUN mv data /data \
    && ln -s /data

VOLUME /data

COPY docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 7474 7473 7687

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["neo4j"]
