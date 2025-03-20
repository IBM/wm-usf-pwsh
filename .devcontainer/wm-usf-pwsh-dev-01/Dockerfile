ARG __ubuntu_tag=24.04
FROM ubuntu:${__ubuntu_tag}

ARG __pester_version=5.7.1
ARG __gid=1234
ARG __gname=vscode
ARG __uid=1234
ARG __uname=vscode
ARG __uhome=/home/${__uname}

RUN apt-get -qy update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -qy install --no-install-recommends \
        apt-transport-https \
        curl \
        git \
        gpg \
        jq \
        less \
        lsb-release \
        software-properties-common \
        ssh \
        unzip \
        wget \
    && . /etc/os-release \
    && wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get -qy update \
    && apt-get -qy install --no-install-recommends powershell \
    && curl https://get.trunk.io -fsSL | bash \
    && rm -rf /var/lib/apt/lists/* \
    && pwsh -Command "Install-Module -Name Pester -RequiredVersion ${__pester_version} -SkipPublisherCheck -Force" \
    && groupadd -g ${__gid} ${__gname} \
    && useradd -rm -d ${__uhome} -s /bin/bash -g ${__gid} -u ${__uid} ${__uname} \
    && chown -R ${__uname}:${__gname} /usr/local/bin

ENV PESTER_VERSION=${__pester_version}

USER ${__uname}

RUN pwsh -Command "Install-Module -Name Pester -RequiredVersion ${__pester_version} -SkipPublisherCheck -Force"