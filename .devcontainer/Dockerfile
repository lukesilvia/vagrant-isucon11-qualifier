FROM ruby:3.0.2-bullseye
ARG UID=1000
RUN useradd --shell /bin/bash -m -u ${UID} isucon && \
  mkdir -p /home/isucon/workspace && \
  apt-get update && apt-get -y install rsync default-mysql-client redis-server
USER ${UID}