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

