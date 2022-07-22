#!/bin/bash

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
DECOLOR="\e[0m"

function usage {
    echo "Usage: $0 [master|worker]"
}

function check {
# check if user is root
if ! [ $UID == "0" ]; then
    echo -e "${RED}You should run this script with \"root\" user.${DECOLOR}"
    exit 1
fi

# check if cri-dockerd binary is available in current directory
CRI_DOCKERD=$(find . -maxdepth 1 -type f -name cri-dockerd* | sort | tail -1)
if [ -z $CRI_DOCKERD ]; then
    echo -e "${YELLOW}\"cri-dockerd\" binary package not found in current directory."
    echo -e "You can download the appropriate package from this link:"
    echo -e "https://github.com/Mirantis/cri-dockerd/releases/latest${DECOLOR}"
    exit 1
else
    echo -e "${GREEN}Found \"$CRI_DOCKERD\" package...${DECOLOR}"
fi

# check if os is ubuntu
if ! cat /etc/os-release | grep -i ubuntu > /dev/null; then
    echo -e "${RED}This script currently works only on \"Ubuntu\".${DECOLOR}"
    exit 1
else
    echo -e "${GREEN}\"Ubuntu\" operating system detected...${DECOLOR}"
fi
}

function common_install {
echo -e "${GREEN}Installing \"Docker\"...${DECOLOR}"
echo -e "${GREEN}Removing old version...${DECOLOR}"
apt-get -q -y remove docker docker-engine docker.io containerd runc
echo -e "${GREEN}Installing requirements...${DECOLOR}"
apt-get -q update
apt-get -q -y install ca-certificates curl gnupg lsb-release
echo -e "${GREEN}Importing \"GPG\" keys...${DECOLOR}"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo -e "${GREEN}Adding \"Docker\" repositories...${DECOLOR}"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
echo -e "${GREEN}Installing \"Docker\"...${DECOLOR}"
apt-get -q update
apt-get -q -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
echo -e "${GREEN}Installing \"cri-dockerd\"...${DECOLOR}"
dpkg -i ./cri-dockerd_0.2.3.3-0.ubuntu-jammy_amd64.deb
}

function master_install {
echo -e "${GREEN}Configuring master node's kernel modules...${DECOLOR}"
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay > /dev/null
modprobe br_netfilter > /dev/null

echo -e "${GREEN}Configuring master node's network...${DECOLOR}"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system > /dev/null
}

function worker_install {
echo -e "${GREEN}Installing requirements...${DECOLOR}"
apt-get -q update
apt-get -q -y install apt-transport-https
echo -e "${GREEN}Importing \"GPG\" keys...${DECOLOR}"
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
  https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo -e "${GREEN}Adding \"K8s\" repositories...${DECOLOR}"
echo \
  "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
  https://apt.kubernetes.io/ kubernetes-xenial main" | \
  tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
echo -e "${GREEN}Installing \"K8s\"...${DECOLOR}"
apt-get -q update
apt-get -q -y install kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
}

case $1 in
    master)
      check
      common_install
      master_install
      worker_install
    ;;

    worker)
      check
      common_install
      worker_install
    ;;

    *)
      usage
      exit 1
    ;;
esac
