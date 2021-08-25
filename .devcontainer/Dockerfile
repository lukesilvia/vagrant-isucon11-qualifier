FROM ruby:3.0.2-bullseye

ARG UID=1000
ARG ALP_VERSION=v1.0.8

RUN useradd --shell /bin/bash -m -u ${UID} isucon && \
  mkdir -p /home/isucon/workspace && \
  apt-get update && apt-get -y install rsync default-mysql-client redis-server && \
  cd /tmp; curl -f -s -OL https://github.com/tkuchiki/alp/releases/download/${ALP_VERSION}/alp_linux_amd64.zip && \
  unzip alp_linux_amd64.zip; install alp /usr/local/bin/alp

USER ${UID}