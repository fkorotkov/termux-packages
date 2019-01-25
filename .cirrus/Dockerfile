FROM ubuntu:bionic

COPY scripts/setup-ubuntu.sh /tmp/setup-ubuntu.sh
COPY scripts/setup-android-sdk.sh /tmp/setup-android-sdk.sh
COPY scripts/properties.sh /tmp/properties.sh

RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install sudo
RUN bash /tmp/setup-ubuntu.sh
RUN bash /tmp/setup-android-sdk.sh
