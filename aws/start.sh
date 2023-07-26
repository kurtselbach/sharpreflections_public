#!/bin/bash

if [[ ! "$1" ]]; then
	echo
	echo 'Type how nodes do you need. For example: ./start.sh N'
	echo
	exit
fi

rm -rf /tmp/sbatch.log
#sudo systemctl restart slurmctld

if [[ "$(sinfo | grep -w -E 'idle~|alloc' | grep -v 'alloc#' | awk '{print $4}' | awk -F',' '{sum+=$1;}END{print sum;}')" -lt "$1" ]]; then
	echo
	echo "You don't have free $1 nodes"
	echo
	sinfo
	echo
	exit
fi

if [[ "$1" ]]; then
	sbatch -N $1 /lustre/job.sh > /tmp/sbatch.log
fi

job=$(awk '{print $4}' /tmp/sbatch.log)

echo
echo 'Start job '$job' on '$1' node(s). Waiting...'
sleep 5

while [[ "$(squeue -j $job | grep hpc | awk '{print $5}')" == "CF" ]]
do
	sleep 5
done

while [[ ! "$(squeue -j $job | grep hpc | awk '{print $5}')" == "R" ]]
do
	echo 'Nodes are not ready. Waiting...'
	sleep 5
done

echo 'Start PreStackPro'

NodeFile=/lustre/NodeFile
rm -rf $NodeFile && touch $NodeFile

nodes=$(sinfo -o "%o" | grep -v -E 'hpc|NODE_ADDR' | xargs)

for i in $nodes
do
	grep -w $i /etc/hosts | awk '{print $3}' >> $NodeFile
done

pspsetting_ramfactor=".70"
usemem="99999999999999"

for node in $nodes; do
	memtotal=$(ssh $node grep MemTotal /proc/meminfo)
	membytes=$(echo $memtotal | awk {'print $2'})
	if [ "$membytes" -lt "$usemem" ]; then
		hostname_lowestram=$node
		usemem=$membytes
	fi
done

memtotal=$(echo $usemem| xargs -I {} echo "scale=1; {}/1024^2" | bc)
memforuse=$(echo "$memtotal * $pspsetting_ramfactor" | bc -l)
pspsetting_ram=$(echo $memforuse | awk '{printf("%d\n",$1 + 0.5)}')

/lustre/PreStackPro/662/bin/PreStackPro -a -u pspuser -b /lustre/PreStackPro/662/bin/PreStackProBackend --ssh-private-key ~/.ssh/id_rsa -m $(head -1 $NodeFile) --nodefile $NodeFile -s $pspsetting_ram -p /lustre \
--shutdown-script /lustre/shutdown.sh

echo
echo 'Check slurm jobs. Waiting...'
sleep 3

if [[ $(squeue | grep hpc ) ]]; then
	echo 'You need to remove all jobs manually or start /lustre/shutdown.sh'
else
	echo 'Delete all jobs.'
fi