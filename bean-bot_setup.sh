#!/usr/bin/env bash

# Setup script environment
set -o errexit  #Exit immediately if a pipeline returns a non-zero status
set -o errtrace #Trap ERR from shell functions, command substitutions, and commands from subshell
set -o nounset  #Treat unset variables as an error
set -o pipefail #Pipe will exit with last non-zero status if applicable
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap 'die "Script interrupted."' INT

export BLIZZARD_CLIENTID=$1
export BLIZZARD_CLIENTSECRET=$2
export BOT_TOKEN=$3
export BDB_CONNECTION=$4

function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR:LXC] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}

# Prepare container OS
msg "Setting up container OS..."
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
apt-get -y purge openssh-{client,server} >/dev/null
apt-get autoremove >/dev/null

# Update container OS
msg "Updating container OS..."
apt update &>/dev/null
apt-get -qqy upgrade &>/dev/null

# Install prerequisites
msg "Installing prerequisites..."
apt-get -qqy install \
    curl \
    sudo &>/dev/null

# Installing git
msg "Installing git..."
apt-get install git -y &>/dev/null
 
# Installing npm
msg "Installing npm..."
apt-get install npm -y &>/dev/null

# Installing node-js
msg "Installing node-js..."
apt-get install nodejs -y &>/dev/null

# Installing pm2
msg "Installing pm2..."
npm install pm2 -g &>/dev/null

# Setting up bean-bot source code
git clone https://github.com/doron-nathan-epstein/bean-bot.git bean-bot
cd bean-bot
npm install

# Setting up pm2
msg "Setting up pm2..."
pm2 start index.js
sudo env PATH=$PATH:/usr/local/bin pm2 startup -u root

# Customize container
msg "Customizing container..."
rm /etc/motd # Remove message of the day after login
rm /etc/update-motd.d/10-uname # Remove kernel information after login
touch ~/.hushlogin # Remove 'Last login: ' and mail notification after login
GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
mkdir -p $(dirname $GETTY_OVERRIDE)
cat << EOF > $GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
systemctl daemon-reload
systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')

# Cleanup container
msg "Cleanup..."
rm -rf /bean-bot_setup.sh /var/{cache,log}/* /var/lib/apt/lists/*
