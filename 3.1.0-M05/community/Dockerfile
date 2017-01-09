FROM openjdk:8-jre

ENV NEO4J_SHA256 ccdd4b7d7320a0ecc78f9d8f26bc90d20de8d6ec3b517ffbc129ba9ff8d3f4d6
ENV NEO4J_URI http://dist.neo4j.org/neo4j-community-3.1.0-M05-unix.tar.gz



RUN curl --fail --silent --show-error --location --output neo4j.tar.gz $NEO4J_URI \
    && echo "$NEO4J_SHA256 neo4j.tar.gz" | sha256sum --check --quiet - \
    && tar --extract --file neo4j.tar.gz --directory /var/lib \
    && mv /var/lib/neo4j-* /var/lib/neo4j \
    && rm neo4j.tar.gz

WORKDIR /var/lib/neo4j

RUN mv data /data \
    && ln --symbolic /data

VOLUME /data

COPY docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 7474 7473 7687

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["neo4j"]
