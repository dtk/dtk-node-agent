#!/usr/bin/env bash

. /host_volume/dtk.config

GIT_PORT=${GIT_PORT-2222}
PBUILDERID=${PBUILDERID-docker-executor}

cat << EOF > /etc/dtk/arbiter.cfg
stomp_url = ${PUBLIC_ADDRESS}
stomp_port = 6163
stomp_username = ${USERNAME}
stomp_password = ${STOMP_PASSWORD}
arbiter_topic = /topic/arbiter.${USERNAME}.broadcast
arbiter_queue = /queue/arbiter.${USERNAME}.reply
git_server = "ssh://${USERNAME}@${PUBLIC_ADDRESS}:${GIT_PORT}"
pbuilderid = ${PBUILDERID}
private_key = /host_volume/arbiter/arbiter_remote
EOF

/opt/puppet-omnibus/embedded/bin/ruby start.rb --foreground
