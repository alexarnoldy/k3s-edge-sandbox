#!/bin/bash 

## Script to run Terraform to create an openSUSE JeOS cluster on the local system 
## then run K3sup to create a K3s cluster on it, and finally import the cluster 
## into a Rancher server instance.

## 02/17/2021 - alex.arnoldy@suse.com

################################################################################################
##  IMPORTANT:	This script defines simulated edge locations in the k3s_edge_locations.conf file
##		for subnet, server & agent specs and cluster labels.
################################################################################################
##		    Using this script to deploy HA server nodes requires a load balancer 
## SUPER IMPORTANT: for the Kubernetes API server, port 6443
################################################################################################

## The Rancher server is identified in the rancher2.tf file
## Rancher tokens need to be kept in a ~/.rancher_tokens file in this user's home directory
## Format needs to be:
## export RANCHER_ACCESS_KEY=token-xxxxx
## export RANCHER_SECRET_KEY=xxxxxxxxxxxxxxxx
source ${HOME}/.rancher_tokens

RED='\033[0;31m'
LCYAN='\033[1;36m'
NC='\033[0m' # No Color
EDGE_LOCATION=$1
SSH_USER="ec2-user"
CONFIG_FILE="./k3s_edge_locations.conf"
INSTALLED_K3s_VERSION="v1.20.4+k3s1"


## Test for at least one argument provided with the command
[ -z "$1" ] && echo "Usage: k3s-cluster-create.sh  <name of predefined edge location>  <Optional domain name>" && exit


## Ensure the required utilities are present before continuing
#for UTILITY in nc git terraform k3sup kubectl 
for UTILITY in nc git terraform 
do
	which ${UTILITY} &> /dev/null || { echo "The ${UTILITY} utility is not in your path or is not present on this system. Please resolve before attempting another run. Exiting."; exit; }
done


## Set DOMAIN_NAME to second argument, if provided
[ -z "$2" ] && DOMAIN_NAME=[A-Za-b0-9] || DOMAIN_NAME=$2


## Set EDITOR to vi, if not set
#[ -z "$EDITOR" ] && export EDITOR=vi


## Gather the configuration out of the config file:
## Note that the array is populated with specific info in each element
## Review the config file before applying the config or bad things might happen
## Example: 
## 10.0.11.0./24 site-1 3/t2.small 0/t2.small status=standby
EDGE_LOCATION_CONFIG=($(grep ${EDGE_LOCATION} ${CONFIG_FILE} | head -1))

#### Changing the format of the config file for AWS changed how the data has to be parsed. Now ALL_SERVERS=NUM_SERVERS and ALL_AGENTS=NUM_AGENTS
## Discover up to 3 server nodes to be used in this edge location.
ALL_SERVERS=$(echo ${EDGE_LOCATION_CONFIG[2]} | awk -F/ '{print$1}')
#ALL_SERVERS=($(grep -iw ${EDGE_LOCATION} ${CONFIG_FILE} | grep -i ${DOMAIN_NAME} | grep -i server | awk -F# '{print$1}' | sort -k 1,1))

## Discover agent nodes to be used in this edge location. 
ALL_AGENTS=$(echo ${EDGE_LOCATION_CONFIG[3]} | awk -F/ '{print$1}')
#ALL_AGENTS=($(grep -iw ${EDGE_LOCATION} ${CONFIG_FILE} | grep -i ${DOMAIN_NAME} | grep -i agent | awk -F# '{print$1}' | sort -k 1,1))


## FIRST_SERVER_HOSTNAME will used in the following test and later in the script
FIRST_SERVER_HOSTNAME=${EDGE_LOCATION_CONFIG[1]}

## Test to see if the provided argument matches a defined edge location
[ -z "${FIRST_SERVER_HOSTNAME}" ]  && echo -e "Edge location \"${LCYAN}${EDGE_LOCATION}${NC}\" is not defined." && exit



## Establish the last index in the arrays
FINAL_AGENT_INDEX=$(echo $((${ALL_AGENTS}-1)))
FINAL_SERVER_INDEX=$(echo $((${#ALL_SERVERS[@]}-1)))

## Establish the number of servers and agents in the arrays:
NUM_SERVERS=$(echo ${EDGE_LOCATION_CONFIG[2]} | awk -F/ '{print$1}')
NUM_AGENTS=$(echo ${EDGE_LOCATION_CONFIG[3]} | awk -F/ '{print$1}')


## Set the SERVER_INSTANCE_TYPE and AGENT_INSTANCE_TYPE 
SERVER_INSTANCE_TYPE=$(echo ${EDGE_LOCATION_CONFIG[2]} | awk -F/ '{print$2}')

## Set AGENT_INSTANCE_TYPE only if there are agents specified
[ ${ALL_AGENTS} -gt 0 ] && AGENT_INSTANCE_TYPE=$(echo ${EDGE_LOCATION_CONFIG[3]} | awk -F/ '{print$2}')



## Create the JeOS cluster nodes. Saves the state files to specific locations to keep things tidy
## Determine the VPC_CIDR based on the SUBNET CIDR
VPC_PUBLIC_SUBNETS=$(echo \"${EDGE_LOCATION_CONFIG[0]}\") 
VPC_CIDR=$(echo ${EDGE_LOCATION_CONFIG[0]} | awk -F. '{print$1"."$2".0.0/16"}')

## Exctract the cluster_labels
CLUSTER_LABELS=$(echo ${EDGE_LOCATION_CONFIG[4]}) 


## Create a custom tfvars file for this deployment
mkdir -p state/${EDGE_LOCATION}/
cat <<EOF> state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfvars
num_servers = ${NUM_SERVERS}
server_instance_type = "${SERVER_INSTANCE_TYPE}"
num_agents = ${NUM_AGENTS}
agent_instance_type = "${AGENT_INSTANCE_TYPE}"
edge_location = "${EDGE_LOCATION}"
vpc_cidr = "${VPC_CIDR}"
vpc_public_subnets = [${VPC_PUBLIC_SUBNETS}]
cluster_labels = {${CLUSTER_LABELS}}
EOF

terraform apply -auto-approve --state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate -var-file=terraform.tfvars -var-file=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfvars

ALL_SERVER_PUBLIC_IPS=($(terraform output -state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate ec2_server_instances_public_ip | egrep -v "\[|\]" | awk -F\, '{print$1}' | sed 's/\"//g'))
#echo ${ALL_SERVER_PUBLIC_IPS[@]}
FIRST_SERVER_PUBLIC_IP=$(terraform output -json -state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate ec2_first_server_instance_public_ip | awk -F\" '{print$2}')
#echo ${FIRST_SERVER_PUBLIC_IP}

ALL_AGENT_PUBLIC_IPS=($(terraform output -state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate ec2_agent_instances_public_ip | egrep -v "\[|\]" | awk -F\, '{print$1}' | sed 's/\"//g'))

#ALL_SERVER_PRIVATE_IPS=($(terraform output -state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate ec2_instance_private_ips | egrep -v "\[|\]" | awk -F\, '{print$1}' | sed 's/\"//g'))
#echo ${ALL_SERVER_PRIVATE_IPS[@]}
FIRST_SERVER_PRIVATE_IP=$(terraform output -json -state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate ec2_first_server_instance_private_ip | awk -F\" '{print$2}')

SSH_KEY_NAME=$(terraform output -json -state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate ssh_key_name  | awk -F\" '{print$2}')

mkdir -p ~/.kube/

## NOTE: Quick way to install first server from the command line:
# K3s_VERSION="v1.20.4+k3s1"; ssh ec2-user@54.153.109.143 sh -c "K3s_VERSION="v1.20.4+k3s1" ; curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${K3s_VERSION}' INSTALL_K3S_EXEC='server --cluster-init --write-kubeconfig-mode=644' sh -s -"


## Ensure the server node is updated and ready before installing K3s 
# Remove any previous entries for this node in the local known_hosts file
ssh-keygen -q -R ${FIRST_SERVER_PUBLIC_IP} -f ${HOME}/.ssh/known_hosts &> /dev/null

## This tests for a shutdown entry to be added to the last log, indicating the node has rebooted
# Disabling this test as AWS cloud instances don't automatically get updated and rebooted (though I could likely do it through cloud-init), and they seem to be very out-of-date so patching takes a long time
#until ssh -o StrictHostKeyChecking=no ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} last -x | grep shutdown &> /dev/null; do echo "Waiting for ${FIRST_SERVER_HOSTNAME} to boot up and update its software..." && sleep 30; done

## Test for sshd to come online after the reboot, then wait ten seconds more for the node to finish booting
until nc -zv ${FIRST_SERVER_PUBLIC_IP} 22 &> /dev/null; do echo "Waiting until ${FIRST_SERVER_HOSTNAME} finishes booting..." && sleep 5; done
echo "Waiting for someone who truly gets me..."
#sleep 10



## Test to see if more than one server is specified
[ ${ALL_SERVERS} -gt 2 ] && CLUSTER="--cluster-init" || CLUSTER=""

## Install first server node
K3s_VERSION="v1.20.4+k3s1"; ssh -q -oStrictHostKeyChecking=no -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} "K3s_VERSION="v1.20.4+k3s1" ; curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${K3s_VERSION}' INSTALL_K3S_EXEC='server ${CLUSTER} --write-kubeconfig-mode=644' sh -s -"

## Enable to download the kubeconfig file for this cluster
#scp ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP}:/etc/rancher/k3s/k3s.yaml ${HOME}/.kube/kubeconfig-${EDGE_LOCATION}




## Wait until the K3s server node is ready before joining the rest of the nodes
ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} "until kubectl get deployment -n kube-system coredns &> /dev/null; do echo "Waiting for the Kubernetes API server to respond..." && sleep 10; done"
sleep 5
ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} "kubectl -n kube-system wait --for=condition=available --timeout=600s deployment/coredns"

## Join the remaining two server nodes to the cluster
	NODE_TOKEN=$(ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} sudo cat /var/lib/rancher/k3s/server/node-token)

for SERVER in $(echo ${ALL_SERVER_PUBLIC_IPS[@]}); do
#for INDEX in 0 1; do 
cat <<EOF> /tmp/${SERVER}.sh
#cat <<EOF> /tmp/${ALL_SERVER_PUBLIC_IPS[INDEX]}.sh
FIRST_SERVER_PRIVATE_IP=${FIRST_SERVER_PRIVATE_IP};
NODE_TOKEN=$(ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} sudo cat /var/lib/rancher/k3s/server/node-token)
K3s_VERSION=${INSTALLED_K3s_VERSION};
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3s_VERSION} K3S_URL=https://${FIRST_SERVER_PRIVATE_IP}:6443 K3S_TOKEN=${NODE_TOKEN} K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC='server' sh -
EOF
	scp -q -i ${HOME}/.ssh/${SSH_KEY_NAME} -o StrictHostKeyChecking=no /tmp/${SERVER}.sh ${SSH_USER}@${SERVER}:~/ 
#	scp -q -i ${HOME}/.ssh/${SSH_KEY_NAME} -o StrictHostKeyChecking=no /tmp/${ALL_SERVER_PUBLIC_IPS[INDEX]}.sh ${SSH_USER}@${ALL_SERVER_PUBLIC_IPS[INDEX]}:~/ 
	ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} -o StrictHostKeyChecking=no ${SSH_USER}@${SERVER} "bash ~/${SERVER}.sh"
#	ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} -o StrictHostKeyChecking=no ${SSH_USER}@${ALL_SERVER_PUBLIC_IPS[INDEX]} "bash ~/${ALL_SERVER_PUBLIC_IPS[INDEX]}.sh"
	sleep 5
#	rm /tmp/${SERVER}.sh
#	rm /tmp/${ALL_SERVER_PUBLIC_IPS[INDEX]}.sh
done




for AGENT in $(echo ${ALL_AGENT_PUBLIC_IPS[@]}); do
cat <<EOF> /tmp/${AGENT}.sh
FIRST_SERVER_PRIVATE_IP=${FIRST_SERVER_PRIVATE_IP}
NODE_TOKEN=$(ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} sudo cat /var/lib/rancher/k3s/server/node-token)
K3s_VERSION=${INSTALLED_K3s_VERSION}
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3s_VERSION} K3S_URL=https://${FIRST_SERVER_PRIVATE_IP}:6443 K3S_TOKEN=${NODE_TOKEN} K3S_KUBECONFIG_MODE="644" sh -
EOF
	scp -q -i ${HOME}/.ssh/${SSH_KEY_NAME} -o StrictHostKeyChecking=no /tmp/${AGENT}.sh ${SSH_USER}@${AGENT}:~/ 
	ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} -o StrictHostKeyChecking=no ${SSH_USER}@${AGENT} "bash ~/${AGENT}.sh"
	sleep 5
#	rm /tmp/${AGENT}.sh
done

#### Disabled until I can separate the provisiong of server and agent nodes in ec2
# Join all agent nodes to the cluster
#for INDEX in $(seq 0 2 ${FINAL_AGENT_INDEX}); do 
#	k3sup join --ip ${ALL_AGENTS[INDEX]} --server-ip ${FIRST_SERVER_IP} --sudo --user ${SSH_USER} 
## --k3s-channel doesn't work with k3sup v0.9.6	
#	k3sup join --ip ${ALL_AGENTS[INDEX]} --server-ip ${FIRST_SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable
#	sleep 5
#done



## Extract and apply the string to deploy the cattle-agent and fleet-agent
#export KUBECONFIG=${HOME}/.kube/kubeconfig-${EDGE_LOCATION}
#kubectl config use-context k3s-${EDGE_LOCATION}

CATTLE_AGENT_STRING=$(grep -w command ${PWD}/state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate | head -1 | awk -F\"command\"\: '{print$2}' | sed -e 's/",//' -e 's/"//' | awk '{print$4}')

## Apply securely, or attempt insecurely if it fails (for any reason)
ssh -q -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP} "kubectl apply -f ${CATTLE_AGENT_STRING} || { curl --insecure -sfL ${CATTLE_AGENT_STRING} | kubectl apply -f -; }"


##Final messages for using and destroying the cluster
echo "export EDGE_LOCATION=${EDGE_LOCATION}; source ${HOME}/.rancher_tokens; terraform destroy -auto-approve --state=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfstate -var-file=terraform.tfvars -var-file=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfvars" > ./bin/destroy_${EDGE_LOCATION}_edge_location.sh

echo -e "######################## ${RED}TO DESTROY THIS CLUSTER, USE THE COMMAND:${LCYAN} ./bin/destroy_${EDGE_LOCATION}_edge_location.sh${NC} "
#echo -e "## ${LCYAN}export EDGE_LOCATION=${EDGE_LOCATION}; source ~/.rancher_tokens; terraform destroy -auto-approve --state=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfstate -var-file=terraform.tfvars -var-file=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfvars${NC}"
#echo "###########################################################################"
echo ""

chmod 755 ./bin/destroy_${EDGE_LOCATION}_edge_location.sh

echo ""; echo -e "Connect to the Rancher server and/or one of the cluster servers, ssh -i ${HOME}/.ssh/${SSH_KEY_NAME} ${SSH_USER}@${FIRST_SERVER_PUBLIC_IP}, to work with this cluster"

