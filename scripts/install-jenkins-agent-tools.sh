#!/bin/bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg unzip git python3 fontconfig openjdk-21-jre

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
  > /etc/apt/sources.list.d/docker.list

curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
chmod a+r /etc/apt/keyrings/hashicorp.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") main" \
  > /etc/apt/sources.list.d/hashicorp.list

curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
chmod a+r /etc/apt/keyrings/trivy.gpg
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb \
  $(. /etc/os-release && echo "${VERSION_CODENAME}") main" \
  > /etc/apt/sources.list.d/trivy.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin terraform trivy

case "$(dpkg --print-architecture)" in
  amd64) aws_arch="x86_64" ;;
  arm64) aws_arch="aarch64" ;;
  *)
    echo "Unsupported AWS CLI architecture: $(dpkg --print-architecture)" >&2
    exit 1
    ;;
esac
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

if ! id jenkins >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash jenkins
fi
usermod -aG docker jenkins
systemctl enable --now docker

echo "Install the Jenkins SSH public key in /home/jenkins/.ssh/authorized_keys."
echo "Configure SonarScanner as a pinned Jenkins Global Tool; do not install AWS access keys."
