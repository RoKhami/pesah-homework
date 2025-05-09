FROM jenkins/jenkins:lts

USER root


RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    curl \
    sudo \
    gnupg \
    lsb-release \
    unzip \
    jq \
    python3 \
    python3-pip \
    groff \
    less


RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws


RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg && \
    echo "deb [arch=amd64] https://download.docker.com/linux/debian bullseye stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

RUN usermod -aG docker jenkins

USER jenkins
