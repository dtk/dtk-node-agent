#!/usr/bin/env bash

. /host_volume/dtk.config

GIT_PORT=${GIT_PORT-2222}
if [[ -z $GIT_USERNAME ]]; then
  GIT_USERNAME=$USERNAME
fi
PBUILDERID=${PBUILDERID-docker-executor}
PRIVATE_KEY_NAME=${PRIVATE_KEY_NAME-arbiter_remote}

if [[ "$SKIP_CONFIG" != true ]]; then
cat << EOF > /etc/dtk/arbiter.cfg
stomp_url = ${PUBLIC_ADDRESS}
stomp_port = 6163
stomp_username = ${STOMP_USERNAME}
stomp_password = ${STOMP_PASSWORD}
arbiter_topic = /topic/arbiter.${STOMP_USERNAME}.broadcast
arbiter_queue = /queue/arbiter.${STOMP_USERNAME}.reply
git_server = "ssh://${GIT_USERNAME}@${PUBLIC_ADDRESS}:${GIT_PORT}"
pbuilderid = ${PBUILDERID}
private_key = /host_volume/arbiter/arbiter_remote
EOF
fi

/opt/puppet-omnibus/embedded/bin/ruby start.rb --foreground
