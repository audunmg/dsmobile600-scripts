FROM localhost/debian:wheezy

RUN apt-get update; apt-get install -qqqy sane-utils

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
