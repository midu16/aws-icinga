# aws-icinga

## Description

Preparing the under-layer configuration and the service-layer configuration in order to install and deploy the icinga2-client monitoring tool.

The infrastructure directory contains the ansible-playbook for the following points:

		- Installes the Amazon Extras repo for epel

		- Copy the local rpm's from the RHEL 7.6

		- Creates a localrepo named icinga, containing additional packages

		- Copy the icinga localrepo configuration file

		- Installes all the local packages

		- Defines the filesystems

		- Defines the mountpoints

		- Create the icinga user

		- Addes the icinga user to icinga, icingacmd and nobody groups

		- Defines a set of icinga sudo rules.

The service directory contains the ansible-playbook for the following points:
		
		- Confingure, Install the icinga2-clinet:

					-
	
		- Regenerates the icinga2-client <-> icinga2-satellite certificates

## Configuration workflow

It first creates on an specific VM which will share the subnet with the the rest of the VMs or the access to this one is known by the rest of the AWS VMs which will suppose to have the icinga2-client installed. This VM will be called, from now on, the icinga2-repo-server VM. This VM will be the only point of access to the local rpm's by the rest of the AWS VMs. 

Taking this choise it will facilitate also the process of updating the icinga2-client VMs. Instead of distributing the localhost rpm's those are centralized. Another advantage it will be the deployment time, because the localhost rpm's will be copied to the target host only once, for the icinga2-repo-server, not for N AWS VMs.



## Building the on-premises infrastructure

In order to obtain the Amazon-linux virtual machine for most common used hypervisors (VMWare, KVM, VirtualBox and Microsoft Hyper-V) follow the instructions on the following link:
```
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-linux-2-virtual-machine.html
```



## Structure

Ansible-playbook is split in two main roles:
		
		- infrastructure
	
		- service


## Contact

e-mail: idumihai16@gmail.com

