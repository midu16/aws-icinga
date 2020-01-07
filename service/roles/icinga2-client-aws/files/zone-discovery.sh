#!/usr/bin/bash

# Andreas Baumgaertner @ OSS
# V1.1 - 20190904

# history:
# v1.1 - env input, json output
# V1.0 - initial version

# output:
# [icinga@avl4083t ~]$ ./zone_detection.sh dev
# { zone: DMZ , satellite1: avl4082t.it.internal , satellite2:  }

# exit codes:
# exit code 0 - json output for zone written to stdout
# exit code 1 - incorrect command line argument
# exit code 2 - <> 1 Zone found - ERROR
# exit code 3 - too many satellites found per zone - ERROR
# exit code 99 - ncat (nc) is not installed or not available in path - ERROR

# do not change order of init
if [ $# -ne 1 ]
then
	echo "usage: zone_detection [dev|prod]"
	exit 1
fi

# max. satellites per zone in json output for ansible tower
limit_satellites=2

# associative array for zones
declare -A icinga2_zones

# associative array for result to avoid dupplicates
declare -A icinga2_clientzone

# lowercase compare
if [ ${1,,} == "prod" ]
then
	# prod - maintain zones here!
	icinga2_zones[avl4122p.it.internal]=AccessNetwork
	icinga2_zones[avl4133p.it.internal]=AccessNetwork
	icinga2_zones[avl4134p.it.internal]=Core
	icinga2_zones[avl4121p.it.internal]=Monitoring
	icinga2_zones[avl4135p.it.internal]=Application
	icinga2_zones[avl4136p.it.internal]=Application
	icinga2_zones[avl4139p.it.internal]=DMZ
	icinga2_zones[avl4163p.it.internal]=T2Special
	icinga2_zones[avl4274p.it.internal]=PublicInternet
elif [ ${1,,} == "dev" ]
then
	# dev - for development only - do not use for live (test and prod) deployments
	#icinga2_zones[avl2805t.it.internal]=Monitoring
	icinga2_zones[avl4068t.it.internal]=Monitoring
	icinga2_zones[avl2803t.it.internal]=Application
	icinga2_zones[avl4082t.it.internal]=DMZ
	icinga2_zones[avl4138t.it.internal]=AccessNetwork
else
	echo "usage: zone_detection [dev|prod]"
	exit 1
fi

# check if ncat is installed
command -v nc 2>&1 >/dev/null || (echo "ERROR: ncat is not installed. as privileged user: yum install nmap-ncat.x86_64" && exit 99)

# find max number of satellites per zone
declare -A count
max_satellites=0

for K in "${!icinga2_zones[@]}" ; do
    if (( ++count[${icinga2_zones[$K]}] > max_satellites )) ; then
        max_satellites=${count[${icinga2_zones[$K]}]}
    fi
done

# debug
#echo $max_satellites

if [ ${max_satellites} -gt ${limit_satellites} ]
then
	echo "ERROR: currently only ${limit_satellites} satellites per zone are supported from ansible playbook / infrastructure - please ask for codefix and change limit_satellites in this script."
	exit 3
fi

for K in "${!icinga2_zones[@]}"
do 
	# debug
	# echo trying ${K} - ${icinga2_zones[$K]};

	# debug
	#nc -v -z -i 1 -w 1 ${K} 5665 && echo ${icinga2_zones[$K]} reachable || echo ${icinga2_zones[$K]} not reachable

	nc -z -i 1 -w 1 ${K} 5665 && icinga2_clientzone[${icinga2_zones[$K]}]=${icinga2_zones[$K]}
done

# debug testing only
#icinga2_clientzone[AccessNetwork]=AccessNetwork

if [ ${#icinga2_clientzone[@]} -ne 1 ]
then
	echo "ERROR: ${#icinga2_clientzone[@]} Zones found."

	# debug
	#echo "${icinga2_clientzone[*]}"
 
	exit 2
fi

# due to ansible limitations, switch to json output
#echo "${icinga2_clientzone[*]}"

output_json="{ zone:  ${icinga2_clientzone[*]} "
# satellite counter
i=1

# assemble satellites
for K in "${!icinga2_zones[@]}"
do 
	if [ "${icinga2_clientzone[*]}" == ${icinga2_zones[$K]} ]
	then
		output_json+=" , satellite${i}: $K "
		((i++))
	fi

	# debug
	#echo ${output_json}
done

while [ $i -le $max_satellites ];
do
	output_json+=" , satellite${i}: '' "
	((i++))
done

output_json+=" }"

echo ${output_json}