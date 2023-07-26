#!/bin/bash -e

### PreStackPro need this packages ###
sudo yum install -y jq screen libGLU libXtst xauth numactl libXcomposite libXcursor fontconfig \
	libXrandr libEGL libX11 infiniband-diags libibverbs-utils qt5-qtbase-gui snapd-qt-qml qt5-qtsvg \
	qt5-qtwebchannel qt5-qtx11extras qt5-qtwebengine mesa-libGLU qt5-qtlocation libxkbcommon-x11 pciutils bc wget

### memlock settings ###
sudo echo "*          -       memlock   unlimited" >> /etc/security/limits.d/10-memlock.conf

# slurm
#sudo sed -i 's/ResumeTimeout=1800/ResumeTimeout=800/g' /etc/slurm/slurm.conf
#sudo systemctl restart slurmctld
#sudo systemctl enable slurmctld

wget https://raw.githubusercontent.com/kurtselbach/sharpreflections_public/main/aws/start.sh -O /data_parallel/start.sh
