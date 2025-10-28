#!/bin/bash

sudo useradd -m sysadmin

echo "sysadmin:Sptech#2024" | sudo chpasswd

sudo usermod -aG sudo sysadmin
sudo mkdir -p /home/sysadmin/.ssh
sudo cp /home/ubuntu/.ssh/authorized_keys /home/sysadmin/.ssh/
sudo chown sysadmin:sysadmin -R /home/sysadmin/.ssh/authorized_keys

# Instalando o docker
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl unzip
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo groupadd docker

sudo usermod -aG docker ubuntu
sudo usermod -aG docker sysadmin

sudo apt-get install -y openjdk-21-jdk

# Instalando AWS 
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

cd /home/ubuntu
git clone https://github.com/fsFernando072/SyncHeart-Infra

cp SyncHeart-Infra/docker-compose.yml ./
rm -rf SyncHeart-Infra