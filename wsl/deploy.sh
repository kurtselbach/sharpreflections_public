#!/bin/bash
clear
echo "Starting Sharp Reflections WSL Deployment script"
echo "Updating system and installing requried packages"
apt-get update
apt-get install sshfs rpm2cpio libegl1 libglu1-mesa libibverbs1 libfreetype6 libnss3 libxtst6 libxcomposite1 qt5* libfontconfig mesa-utils keychain fping -y
