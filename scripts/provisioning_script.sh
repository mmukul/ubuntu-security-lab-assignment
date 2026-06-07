#!/bin/bash
set -e

echo "Starting Provisioning: Updating system..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y curl wget git vim unzip python3-pip python3-venv apt-transport-https gnupg lsb-release default-jre unzip snapd docker.io docker-compose-v2 nodejs npm binwalk

echo "========================================="
echo " Configuring SSH"
echo "========================================="

systemctl enable ssh
systemctl restart ssh || true

# ==========================================
# 1. Install Trivy (Container/FS Scanner)
# ==========================================
echo "Installing Trivy..."
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# ==========================================
# 2. Install ZAP (Zed Attack Proxy)
# ==========================================
echo "Installing ZAP..."
# The snap package is the most reliable way to keep ZAP automatically updated on Ubuntu
sudo snap install zaproxy --classic
# Create a convenient symlink so it can be called directly via 'zap'
sudo ln -s /snap/bin/zaproxy /usr/local/bin/zap

# ==========================================
# 3. Install ScoutSuite (Multi-Cloud Auditor)
# ==========================================
echo "Installing ScoutSuite..."
sudo mkdir -p /opt/scoutsuite
# Ubuntu 24.04 enforces PEP 668, so we must install Python tools in a virtual environment
sudo python3 -m venv /opt/scoutsuite/venv
sudo /opt/scoutsuite/venv/bin/pip install --upgrade pip
sudo /opt/scoutsuite/venv/bin/pip install scoutsuite
# Symlink executable to PATH
sudo ln -s /opt/scoutsuite/venv/bin/scout /usr/local/bin/scoutsuite


echo "========================================="
echo " Installing Docker"
echo "========================================="

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker packer || true

echo "========================================="
echo " Installing Greenbone Community Edition"
echo "========================================="

mkdir -p /opt/greenbone
cd /opt/greenbone

curl -L \
https://greenbone.github.io/docs/latest/_static/docker-compose.yml \
-o docker-compose.yml

docker compose pull || true
docker compose up -d || true

echo "========================================="
echo " Creating Login Banner"
echo "========================================="

cat > /etc/profile.d/security-lab-info.sh << 'EOF'
#!/bin/bash

IP=$(hostname -I | awk '{print $1}')

echo ""
echo "===================================================="
echo " Ubuntu Security Lab"
echo "===================================================="
echo " SSH        : ssh packer@${IP}"
echo " Greenbone  : https://${IP}:9392"
echo ""
echo " Containers : docker ps"
echo " Logs       : docker compose -f /opt/greenbone/docker-compose.yml logs"
echo "===================================================="
echo ""
EOF

chmod +x /etc/profile.d/security-lab-info.sh

echo "========================================="
echo " Creating Helper Command"
echo "========================================="

cat > /usr/local/bin/lab-info << 'EOF'
#!/bin/bash

IP=$(hostname -I | awk '{print $1}')

echo ""
echo "===================================================="
echo " Ubuntu Security Lab"
echo "===================================================="
echo " IP Address : ${IP}"
echo " SSH        : ssh packer@${IP}"
echo " Greenbone  : https://${IP}:9392"
echo ""
echo "Commands:"
echo " docker ps"
echo " docker compose -f /opt/greenbone/docker-compose.yml logs"
echo "===================================================="
echo ""
EOF

chmod +x /usr/local/bin/lab-info

echo "========================================="
echo " Validation"
echo "========================================="

docker --version || true
docker compose version || true
ss -tulpn | grep 9392 || true


# ==========================================
# 5. Install Shannon (AI Assisted Pentesting)
# ==========================================
echo "Installing Shannon AI..."
sudo git clone https://github.com/KeygraphHQ/shannon.git /opt/shannon
# Create a helper script for Shannon
cat << 'EOF' | sudo tee /usr/local/bin/shannon
#!/bin/bash
echo "Starting Shannon AI (KeygraphHQ)..."
echo "Note: Shannon requires Docker and an Anthropic API Key (CLAUDE_API_KEY) to run."
cd /opt/shannon
npx --yes tsx src/index.ts "$@" || echo "Please refer to /opt/shannon/README.md for exact configuration instructions."
EOF
sudo chmod +x /usr/local/bin/shannon

# ==========================================
# 6. Install MobSF (Mobile Security Framework)
# ==========================================
echo "Setting up MobSF via Docker..."
# Pre-pull the official Docker image for MobSF
sudo docker pull opensecurity/mobile-security-framework-mobsf:latest
# Create a helper script to easily launch MobSF
cat << 'EOF' | sudo tee /usr/local/bin/start-mobsf
#!/bin/bash
echo "Starting Mobile Security Framework (MobSF)..."
echo "The web interface will be available at http://localhost:8000"
sudo docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest
EOF
sudo chmod +x /usr/local/bin/start-mobsf

# ==========================================
# 7. Install Exploit-DB (Searchsploit) for IoT/Firmware
# ==========================================
# Note: Binwalk is installed via apt at the top of the script
echo "Installing Exploit-DB (Searchsploit)..."
sudo git clone https://github.com/offensive-security/exploitdb.git /opt/exploitdb
sudo ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit
# Create an updater script for the exploit database
cat << 'EOF' | sudo tee /usr/local/bin/update-exploitdb
#!/bin/bash
echo "Updating Exploit-DB..."
cd /opt/exploitdb && git pull origin master
EOF

sudo chmod +x /usr/local/bin/update-exploitdb

echo "Provisioning complete! System is ready to be finalized."
