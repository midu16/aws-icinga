#!/bin/bash

sudo systemctl stop firewalld
sudo systemctl disable firewalld

#sudo mkdir /localrepo if the directory doesnt exists
if [ -d "/localrepo"]
then 
    echo "The Directory /localrepo exists!"
else 
    sudo mkdir /localrepo
    echo "The Directory /localrepo was created!"
fi

if [ -e "/etc/yum.repos.d/local.repo" ]; then
  echo "File /etc/yum.repos.d/local.repo already exists!"
else
  sudo echo -e "[centos7]\nname=centos7\nbaseurl=file:///localrepo/\nenabled=1\ngpgcheck=0">> /etc/yum.repos.d/local.repo
fi

sudo createrepo /localrepo/

sudo yum clean all

sudo yum repolist all

