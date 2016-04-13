FROM ubuntu:14.04
MAINTAINER dduvnjak <dario@atlantbh.com>

COPY . /usr/share/dtk/dtk-node-agent
COPY docker/init.sh /

RUN /usr/share/dtk/dtk-node-agent/install_agent.sh
RUN mkdir /etc/dtk

WORKDIR /usr/share/dtk/dtk-arbiter

CMD ["/init.sh"]
