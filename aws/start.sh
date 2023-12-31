#!/bin/bash

##############################################
# Variables
##############################################
psprobin='/shared/PreStackPro/bin'
queue_name=$(sinfo -s -h | awk '{print $1}' | sed 's/*//g')

##############################################
# Help
##############################################
if [[ ! "$1" ]]; then
        echo "Please specify the number of nodes you require: ./start.sh N"
        echo "To request 4 nodes please launch like this: ./start.sh 4"
	exit
fi

##############################################
# Check free available nodes
##############################################
rm -rf /tmp/sbatch.log

if [[ "$(sinfo | grep -w -E 'idle|alloc' | grep -v 'alloc#' | awk '{print $4}' | awk -F',' '{sum+=$1;}END{print sum;}')" -lt "$1" ]]; then
	echo
	echo "You don't have free $1 nodes"
	echo
	sinfo
	echo
	exit
fi

##############################################
# Add job script
##############################################
cat << EOF >/shared/job.sh
#!/bin/bash
tail -f /dev/null
EOF

##############################################
# Add new job
##############################################
if [[ "$1" ]]; then
	sbatch -N $1 /shared/job.sh > /tmp/sbatch.log
	if [ ! "$?" -eq 0 ]; then
		echo "Unable to submit job, is compute fleet running?"
		cat /tmp/sbatch.log
		exit
	fi
fi


job=$(awk '{print $4}' /tmp/sbatch.log)

echo
echo 'Start job '$job' on '$1' node(s). Waiting...'
sleep 5

while [[ "$(squeue -j $job | grep $queue_name | awk '{print $5}')" == "CF" ]]
do
	sleep 5
done

while [[ ! "$(squeue -j $job | grep $queue_name | awk '{print $5}')" == "R" ]]
do
	echo 'Nodes are not ready. Waiting...'
	sleep 5
done

echo 'Start PreStackPro'

NodeFile=/shared/NodeFile
rm -rf $NodeFile && touch $NodeFile

#nodes=$(sinfo -o "%o" | grep -v -E "$queue_name|NODE_ADDR" | xargs)

#for i in $nodes
#do
#	grep -w $i /etc/hosts | awk '{print $3}' >> $NodeFile
#done

nodes=$(sinfo --states=MIX -hN | awk '{print $1}')
sinfo --states=MIX -hN | awk '{print $1}' > $NodeFile

##############################################
# Set memory size
##############################################
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

##############################################
# Check ssh key
##############################################
if [ -f "$HOME/.ssh/id_ed25519" ]; then
	sshkeypath="$HOME/.ssh/id_ed25519"
else
	sshkeypath="$HOME/.ssh/id_rsa"
fi	

##############################################
# Add shutdown script
##############################################
rm /shared/shutdown.sh
cat << EOF > /shared/shutdown.sh
#!/bin/bash
for i in $(squeue | grep $queue_name | awk '{print $1}' | xargs)
do
	scancel \$i
done
EOF
chmod +x /shared/shutdown.sh

##############################################
# Start PreStack Pro
##############################################
$psprobin/PreStackPro -u $(echo $USER) -b $psprobin/PreStackProBackend --ssh-private-key $sshkeypath -m $(head -1 $NodeFile) --nodefile $NodeFile -s $pspsetting_ram -p /shared \
--shutdown-script /shared/shutdown.sh

##############################################
# Remove all jobs
##############################################
echo
echo 'Check slurm jobs. Waiting...'
sleep 3

if [[ $(squeue | grep $queue_name ) ]]; then
	echo 'You need to remove all jobs manually or start /shared/shutdown.sh'
else
	echo 'Delete all jobs.'
fi
