#!/bin/bash

cd $HOME/neo4j
mkdir apoc
cd apoc
mkdir 3.2.9
cd 3.2.9

wget https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/3.2.3.6/apoc-3.2.3.6-all.jar

cd $HOME/docker-neo4j-publish

docker run \
    --publish=7474:7474 --publish=7687:7687 \
    --volume=$HOME/neo4j/data:/data \
    --volume=$HOME/neo4j/logs:/logs \
    --volume=$HOME/neo4j/apoc/3.2.9:/plugins \
    --name=abbv_influencemap_neo4j \
    --env=NEO4J_dbms_allow__format__migration=true \
    --env=NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
	--env=NEO4J_apoc_export_file_enabled=true \
    --env=NEO4J_apoc_import_file_enabled=true \
    --env=NEO4J_apoc_import_file_use__neo4j__config=true \
    rmarkbio/neo4j_3.2.9_enterprise:first