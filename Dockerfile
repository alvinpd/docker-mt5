FROM ubuntu:20.04

WORKDIR /tmp/

RUN set ex; \
    dpkg --add-architecture i386; \
    DEBIAN_FRONTEND=noninteractive apt-get update -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        binutils \
        cabextract \
        cpulimit \
        curl \
        fluxbox \
        gpg-agent \
        imagemagick \
        less \
        nginx \
        openssh-server \
        p7zip \
        silversearcher-ag \
        software-properties-common \
        sudo \
        unzip \
        vim \
        wget \
        x11vnc \
        xvfb \
        xz-utils

#-----------------------------------------------------------------------------

# https://wiki.winehq.org/Ubuntu

RUN set -ex; \
    wget -nc https://dl.winehq.org/wine-builds/winehq.key; \
    apt-key add winehq.key; \
    apt-add-repository https://dl.winehq.org/wine-builds/ubuntu/; \
    DEBIAN_FRONTEND=noninteractive apt-get update -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends \
        winehq-stable; \
    rm winehq.key

RUN set -ex; \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
    chmod +x winetricks; \
    mv winetricks /usr/local/bin

COPY waitonprocess.sh /docker/
RUN chmod a+rx /docker/waitonprocess.sh

#----------------------------------------------------------------------------

ARG USER=mt5-trader
ARG HOME=/home/$USER
ARG USER_ID=1000
# To accss the values from children containers
ENV USER=$USER \
    HOME=$HOME

RUN set -ex; \
    adduser --disabled-password --gecos "" --shell /bin/bash $USER; \
    adduser $USER sudo; \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers; \
    echo "Set disable_coredump false" >> /etc/sudo.conf

USER $USER

# WINEDLLOVERRIDES="mscoree,mshtml="
# -> it means don't worry about missing gecko
# -> this is fine as as we won't be looking at doc
USER $USER
ENV WINEARCH=win64 \
    WINEPREFIX=$HOME/.wine \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    DISPLAY=:1 \
    SCREEN_NUM=0 \
    SCREEN_WHD=1366x768x24
RUN set -ex; \
    wine wineboot --init; \
    /docker/waitonprocess.sh wineserver

USER root

#----------------------------------------------------------------------------
# ssh

ADD sshd_config /etc/sshd/sshd_config
ADD authorized_keys $HOME/.ssh/authorized_keys

RUN chown -R $USER:$USER $HOME/.ssh

#----------------------------------------------------------------------------
# MT5

ENV STORE=$HOME/store
ENV MT5=$WINEPREFIX/drive_c/mt5
#ADD staging/mt5.tar.bz2 $MT5
#ADD config/common.ini $MT5
#ADD secrets/startup-demo.ini $MT5/
#ADD secrets/startup-live.ini $MT5/

#----------------------------------------------------------------------------
# nginx

#USER $USER

#RUN mkdir -p $HOME/public; \
#    ln -s $MT5/logs $HOME/public/mt5; \
#    ln -s $MT5/MQL5/Logs $HOME/public/mt5_mql5; \
#    ln -s $SCREENSHOTS $HOME/public/screenshots

#ADD nginx.conf /etc/nginx/nginx.conf

USER $ROOT

#-----------------------------------------------------------------------
# home

ADD bashrc $HOME/.bashrc
ADD inputrc $HOME/.inputrc

RUN set -e; \
    chown $USER:$USER $HOME/.bashrc; \
    chown $USER:$USER $HOME/.inputrc

#-----------------------------------------------------------------------
# boot

# ADD boot.sh /docker/
# RUN chmod +x /docker/boot.sh

USER $USER
WORKDIR $WINEPREFIX/drive_c

ENTRYPOINT ["/bin/bash"]

# /docker/boot.sh [account=demo|live] [strategy] [usd_exposure]
# CMD ["/docker/boot.sh", "demo", "test_connection", "1000"]

