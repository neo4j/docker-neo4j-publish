#!/bin/bash -eu

cmd="$1"

function running_as_root
{
    test "$(id -u)" = "0"
}

function secure_mode_enabled
{
    test "${SECURE_FILE_PERMISSIONS:=no}" = "yes"
}

function is_not_writable
{
    _file=${1}
#    echo "File ${_file} owner stats: $(stat -c %U ${_file}):$(stat -c %G ${_file}) and $(stat -c %u ${_file}):$(stat -c %g ${_file})"
#    echo "comparing to ${userid}:${groupid}"
    test "$(stat -c %U ${_file})" != "${userid}"  &&  \
    test "$(stat -c %u ${_file})" != "${userid}" && \
    ! containsElement "$(stat -c %g ${_file})" "${groups[@]}" && \
    ! containsElement "$(stat -c %G ${_file})" "${groups[@]}"
}

function print_permissions_advice_and_fail ()
{
    _directory=${1}
    echo >&2 "
Folder ${_directory} is not writable for user: ${userid} or group ${groupid} or groups ${groups[@]}, this is commonly a file permissions issue on the mounted folder.

Hints to solve the issue:
1) Make sure the folder exists before mounting it. Docker will create the folder using root permissions before starting the Neo4j container. The root permissions disallow Neo4j from writing to the mounted folder.
2) Pass the folder owner's user ID and group ID to docker run, so that docker runs as that user.
If the folder is owned by the current user, this can be done by adding this flag to your docker run command:
  --user=\$(id -u):\$(id -g)
       "
    exit 1
}

function check_mounted_folder
{
    _directory=${1}
    if is_not_writable "${_directory}"; then
        print_permissions_advice_and_fail "${_directory}"
    fi
}

function check_mounted_folder_with_chown
{
# The /data and /log directory are a bit different because they are very likely to be mounted by the user but not
# necessarily writable.
# This depends on whether a user ID is passed to the container and which folders are mounted.
#
#   No user ID passed to container:
#   1) No folders are mounted.
#      The /data and /log folder are owned by neo4j by default, so should be writable already.
#   2) Both /log and /data are mounted.
#      This means on start up, /data and /logs are owned by an unknown user and we should chown them to neo4j for
#      backwards compatibility.
#
#   User ID passed to container:
#   1) Both /data and /logs are mounted
#      The /data and /logs folders are owned by an unknown user but we *should* have rw permission to them.
#      That should be verified and error (helpfully) if not.
#   2) User mounts /data or /logs *but not both*
#      The  unmounted folder is still owned by neo4j, which should already be writable. The mounted folder should
#      have rw permissions through user id. This should be verified.
#   3) No folders are mounted.
#      The /data and /log folder are owned by neo4j by default, and these are already writable by the user.
#      (This is a very unlikely use case).

    mountFolder=${1}
    if running_as_root; then
        if is_not_writable "${mountFolder}"; then
            # warn that we're about to chown the folder and then chown it
            echo >&2 "Warning: Folder mounted to \"${mountFolder}\" is not writable from inside container. Changing folder owner to ${userid}."
            chown -R "${userid}":"${groupid}" "${mountFolder}"
        fi
    else
        if [ ! -w "${mountFolder}" ]  && [[ "$(stat -c %U ${mountFolder})" != "neo4j" ]]; then
            print_permissions_advice_and_fail "${mountFolder}"
        fi
    fi
}

# If we're running as root, then run as the neo4j user. Otherwise
# docker is running with --user and we simply use that user.  Note
# that su-exec, despite its name, does not replicate the functionality
# of exec, so we need to use both
if running_as_root; then
  userid="neo4j"
  groupid="neo4j"
  groups=($(id -G neo4j))
  exec_cmd="exec gosu neo4j:neo4j"
else
  userid="$(id -u)"
  groupid="$(id -g)"
  groups=($(id -G))
  exec_cmd="exec"
fi
readonly userid
readonly groupid
readonly groups
readonly exec_cmd

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Need to chown the home directory - but a user might have mounted a
# volume here (notably a conf volume). So take care not to chown
# volumes (stuff not owned by neo4j)
if running_as_root; then
    # Non-recursive chown for the base directory
    chown "${userid}":"${groupid}" "${NEO4J_HOME}"
    chmod 700 "${NEO4J_HOME}"
    find "${NEO4J_HOME}" -type d -mindepth 1 -maxdepth 1 -user root -exec chown -R ${userid}:${groupid} {} \;
    find "${NEO4J_HOME}" -type d -mindepth 1 -maxdepth 1 -user root -exec chmod 700 {} \;
fi

if [ "${cmd}" == "dump-config" ]; then
  check_mounted_folder "/conf"
  ${exec_cmd} cp --recursive "${NEO4J_HOME}"/conf/* /conf
  exit 0
fi

# Only prompt for license agreement if command contains "neo4j" in it
if [[ "${cmd}" == *"neo4j"* ]]; then
  if [ "${NEO4J_EDITION}" == "enterprise" ]; then
    if [ "${NEO4J_ACCEPT_LICENSE_AGREEMENT:=no}" != "yes" ]; then
      echo >&2 "
In order to use Neo4j Enterprise Edition you must accept the license agreement.

(c) Neo4j Sweden AB.  2019.  All Rights Reserved.
Use of this Software without a proper commercial license with Neo4j,
Inc. or its affiliates is prohibited.

Email inquiries can be directed to: licensing@neo4j.com

More information is also available at: https://neo4j.com/licensing/


To accept the license agreement set the environment variable
NEO4J_ACCEPT_LICENSE_AGREEMENT=yes

To do this you can use the following docker argument:

        --env=NEO4J_ACCEPT_LICENSE_AGREEMENT=yes
"
      exit 1
    fi
  fi
fi

# Env variable naming convention:
# - prefix NEO4J_
# - double underscore char '__' instead of single underscore '_' char in the setting name
# - underscore char '_' instead of dot '.' char in the setting name
# Example:
# NEO4J_dbms_tx__log_rotation_retention__policy env variable to set
#       dbms.tx_log.rotation.retention_policy setting

# Backward compatibility - map old hardcoded env variables into new naming convention (if they aren't set already)
# Set some to default values if unset
: ${NEO4J_dbms_tx__log_rotation_retention__policy:=${NEO4J_dbms_txLog_rotation_retentionPolicy:-"100M size"}}
: ${NEO4J_wrapper_java_additional:=${NEO4J_UDC_SOURCE:-"-Dneo4j.ext.udc.source=docker"}}
: ${NEO4J_dbms_memory_heap_initial__size:=${NEO4J_dbms_memory_heap_maxSize:-"512M"}}
: ${NEO4J_dbms_memory_heap_max__size:=${NEO4J_dbms_memory_heap_maxSize:-"512M"}}
: ${NEO4J_dbms_unmanaged__extension__classes:=${NEO4J_dbms_unmanagedExtensionClasses:-}}
: ${NEO4J_dbms_allow__format__migration:=${NEO4J_dbms_allowFormatMigration:-}}
: ${NEO4J_dbms_connectors_default__advertised__address:=${NEO4J_dbms_connectors_defaultAdvertisedAddress:-}}
: ${NEO4J_ha_server__id:=${NEO4J_ha_serverId:-}}
: ${NEO4J_ha_initial__hosts:=${NEO4J_ha_initialHosts:-}}
: ${NEO4J_causal__clustering_expected__core__cluster__size:=${NEO4J_causalClustering_expectedCoreClusterSize:-}}
: ${NEO4J_causal__clustering_initial__discovery__members:=${NEO4J_causalClustering_initialDiscoveryMembers:-}}
: ${NEO4J_causal__clustering_discovery__listen__address:=${NEO4J_causalClustering_discoveryListenAddress:-"0.0.0.0:5000"}}
: ${NEO4J_causal__clustering_discovery__advertised__address:=${NEO4J_causalClustering_discoveryAdvertisedAddress:-"$(hostname):5000"}}
: ${NEO4J_causal__clustering_transaction__listen__address:=${NEO4J_causalClustering_transactionListenAddress:-"0.0.0.0:6000"}}
: ${NEO4J_causal__clustering_transaction__advertised__address:=${NEO4J_causalClustering_transactionAdvertisedAddress:-"$(hostname):6000"}}
: ${NEO4J_causal__clustering_raft__listen__address:=${NEO4J_causalClustering_raftListenAddress:-"0.0.0.0:7000"}}
: ${NEO4J_causal__clustering_raft__advertised__address:=${NEO4J_causalClustering_raftAdvertisedAddress:-"$(hostname):7000"}}

# unset old hardcoded unsupported env variables
unset NEO4J_dbms_txLog_rotation_retentionPolicy NEO4J_UDC_SOURCE \
    NEO4J_dbms_memory_heap_maxSize NEO4J_dbms_memory_heap_maxSize \
    NEO4J_dbms_unmanagedExtensionClasses NEO4J_dbms_allowFormatMigration \
    NEO4J_dbms_connectors_defaultAdvertisedAddress NEO4J_ha_serverId \
    NEO4J_ha_initialHosts NEO4J_causalClustering_expectedCoreClusterSize \
    NEO4J_causalClustering_initialDiscoveryMembers \
    NEO4J_causalClustering_discoveryListenAddress \
    NEO4J_causalClustering_discoveryAdvertisedAddress \
    NEO4J_causalClustering_transactionListenAddress \
    NEO4J_causalClustering_transactionAdvertisedAddress \
    NEO4J_causalClustering_raftListenAddress \
    NEO4J_causalClustering_raftAdvertisedAddress

# Custom settings for dockerized neo4j
: ${NEO4J_dbms_tx__log_rotation_retention__policy:=100M size}
: ${NEO4J_dbms_memory_pagecache_size:=512M}
: ${NEO4J_wrapper_java_additional:=-Dneo4j.ext.udc.source=docker}
: ${NEO4J_dbms_memory_heap_initial__size:=512M}
: ${NEO4J_dbms_memory_heap_max__size:=512M}
: ${NEO4J_dbms_connectors_default__listen__address:=0.0.0.0}
: ${NEO4J_dbms_connector_http_listen__address:=0.0.0.0:7474}
: ${NEO4J_dbms_connector_https_listen__address:=0.0.0.0:7473}
: ${NEO4J_dbms_connector_bolt_listen__address:=0.0.0.0:7687}
: ${NEO4J_ha_host_coordination:=$(hostname):5001}
: ${NEO4J_ha_host_data:=$(hostname):6001}
: ${NEO4J_causal__clustering_discovery__listen__address:=0.0.0.0:5000}
: ${NEO4J_causal__clustering_discovery__advertised__address:=$(hostname):5000}
: ${NEO4J_causal__clustering_transaction__listen__address:=0.0.0.0:6000}
: ${NEO4J_causal__clustering_transaction__advertised__address:=$(hostname):6000}
: ${NEO4J_causal__clustering_raft__listen__address:=0.0.0.0:7000}
: ${NEO4J_causal__clustering_raft__advertised__address:=$(hostname):7000}

if [ -d /conf ]; then
    check_mounted_folder "/conf"
    find /conf -type f -exec cp {} "${NEO4J_HOME}"/conf \;
fi

if [ -d /ssl ]; then
    check_mounted_folder "/ssl"
    NEO4J_dbms_directories_certificates="/ssl"
fi

if [ -d /plugins ]; then
    check_mounted_folder "/plugins"
    NEO4J_dbms_directories_plugins="/plugins"
fi

if [ -d /import ]; then
    check_mounted_folder "/import"
    NEO4J_dbms_directories_import="/import"
fi

if [ -d /metrics ]; then
    check_mounted_folder "/metrics"
    NEO4J_dbms_directories_metrics="/metrics"
fi

if [ -d /logs ]; then
    check_mounted_folder_with_chown "/logs"
    NEO4J_dbms_directories_logs="/logs"
fi

if [ -d /data ]; then
    check_mounted_folder_with_chown "/data"
fi


# set the neo4j initial password only if you run the database server
if [ "${cmd}" == "neo4j" ]; then
    if [ "${NEO4J_AUTH:-}" == "none" ]; then
        NEO4J_dbms_security_auth__enabled=false
    elif [[ "${NEO4J_AUTH:-}" == neo4j/* ]]; then
        password="${NEO4J_AUTH#neo4j/}"
        if [ "${password}" == "neo4j" ]; then
            echo >&2 "Invalid value for password. It cannot be 'neo4j', which is the default."
            exit 1
        fi

        if running_as_root; then
            # running set-initial-password as root will create subfolders to /data as root, causing startup fail when neo4j can't read or write the /data/dbms folder
            # creating the folder first will avoid that
            mkdir -p /data/dbms
            chown "${userid}":"${groupid}" /data/dbms
        fi
        # Will exit with error if users already exist (and print a message explaining that)
        # we probably don't want the message though, since it throws an error message on restarting the container.
        neo4j-admin set-initial-password "${password}" 2>/dev/null || true
    elif [ -n "${NEO4J_AUTH:-}" ]; then
        echo >&2 "Invalid value for NEO4J_AUTH: '${NEO4J_AUTH}'"
        exit 1
    fi
fi

# list env variables with prefix NEO4J_ and create settings from them
unset NEO4J_AUTH NEO4J_SHA256 NEO4J_TARBALL
for i in $( set | grep ^NEO4J_ | awk -F'=' '{print $1}' | sort -rn ); do
    setting=$(echo ${i} | sed 's|^NEO4J_||' | sed 's|_|.|g' | sed 's|\.\.|_|g')
    value=$(echo ${!i})
    # Don't allow settings with no value or settings that start with a number (neo4j converts settings to env variables and you cannot have an env variable that starts with a number)
    if [[ -n ${value} ]]; then
        if [[ ! "${setting}" =~ ^[0-9]+.*$ ]]; then
            if grep -q -F "${setting}=" "${NEO4J_HOME}"/conf/neo4j.conf; then
                # Remove any lines containing the setting already
                sed --in-place "/^${setting}=.*/d" "${NEO4J_HOME}"/conf/neo4j.conf
            fi
            # Then always append setting to file
            echo "${setting}=${value}" >> "${NEO4J_HOME}"/conf/neo4j.conf
        else
            echo >&2 "WARNING: ${setting} not written to conf file because settings that start with a number are not permitted"
        fi
    fi
done


[ -f "${EXTENSION_SCRIPT:-}" ] && . ${EXTENSION_SCRIPT}

# Use su-exec to drop privileges to neo4j user
# Note that su-exec, despite its name, does not replicate the
# functionality of exec, so we need to use both
if [ "${cmd}" == "neo4j" ]; then
  ${exec_cmd} neo4j console
else
  ${exec_cmd} "$@"
fi
