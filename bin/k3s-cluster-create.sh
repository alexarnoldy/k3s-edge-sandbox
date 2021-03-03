#!/bin/bash 

## Script to run Terraform to create an openSUSE JeOS cluster on the local system 
## then run K3sup to create a K3s cluster on it, and finally import the cluster 
## into a Rancher server instance.

## 02/17/2021 - alex.arnoldy@suse.com

################################################################################################
##		This script relies on /etc/hosts or DNS (DNS hasn't been tested yet and doesn't
## 		support domain names yet) for IPAM as well as hostname resolution 
## IMPORTANT: 	to discover simulated edge locations. 
##		Ensure either /etc/hosts or DNS is configured to resolve hostnames in the format
## 		of "edge-location"-server-[0-2] and "edge-location"-agent-[0-N]
##		i.e. bangkok-server-0 and bangkok-agent-5
################################################################################################
##		    This script currently does not support HA server nodes.
## SUPER IMPORTANT: Defining more than one server node won't add any value and could potentially
## 		    break the cluster.
################################################################################################

## Rancher tokens need to be kept in a ~/.rancher_tokens file in this user's home directory
## Format needs to be:
## export RANCHER_ACCESS_KEY=token-xxxxx
## export RANCHER_SECRET_KEY=xxxxxxxxxxxxxxxx
source ${HOME}/.rancher_tokens

RED='\033[0;31m'
LCYAN='\033[1;36m'
NC='\033[0m' # No Color
EDGE_LOCATION=$1
SSH_USER="opensuse"


## Test for at least one argument provided with the command
[ -z "$1" ] && echo "Usage: k3s-cluster-create.sh  <name of predefined edge location>  <Optional domain name>" && exit


## Ensure the required utilities are present before continuing
for UTILITY in nc git terraform k3sup kubectl 
do
	which ${UTILITY} &> /dev/null || { echo "The ${UTILITY} utility is not in your path or is not present on this system. Please resolve before attempting another run. Exiting."; exit; }
done


## Set DOMAIN_NAME to second argument, if provided
[ -z "$2" ] && DOMAIN_NAME=[A-Za-b0-9] || DOMAIN_NAME=$2


## Discover up to 3 server nodes to be used in this edge location.
## Note that the array is populated with the IP addresses being the even indices
## and the associated hostnames being the subsequent odd indices
## i.e. ${ALL_SERVERS[0]} is the IP of the first server and ${ALL_SERVERS[1]} is
## the hostname of the first server
#ALL_SERVERS=($(getent hosts ${EDGE_LOCATION}-server-{0..2}))
ALL_SERVERS=($(getent hosts | grep -i ${EDGE_LOCATION} | grep -i ${DOMAIN_NAME} | grep -i server | sort -k 1,1))



## Test to see if the provided argument matches a defined edge location
FIRST_SERVER_HOSTNAME=${ALL_SERVERS[1]}
## FIRST_SERVER_IP will be used later in the script
FIRST_SERVER_IP=${ALL_SERVERS[0]}
[ -z "${FIRST_SERVER_HOSTNAME}" ]  && echo -e "Edge location \"${LCYAN}${EDGE_LOCATION}${NC}\" is not defined." && exit


## Discover up to 25 agent nodes to be used in this edge location. Adjust above 25 as needed.
#ALL_AGENTS=($(getent hosts ${EDGE_LOCATION}-agent-{0..25}))
ALL_AGENTS=($(getent hosts | grep -i ${EDGE_LOCATION} | grep -i ${DOMAIN_NAME} | grep -i agent | sort -k 1,1))


## Establish the last index in the arrays
FINAL_AGENT_INDEX=$(echo $((${#ALL_AGENTS[@]}-1)))
FINAL_SERVER_INDEX=$(echo $((${#ALL_SERVERS[@]}-1)))

## Establish the number of servers and agents in the arrays:
NUM_SERVERS=$(echo $((${#ALL_SERVERS[@]} / 2 )))
NUM_AGENTS=$(echo $((${#ALL_AGENTS[@]} / 2 )))


##Example of how to iterate over the IPs in the array
#for INDEX in $(seq 0 2 ${FINAL_AGENT_INDEX}); do echo ${ALL_AGENTS[INDEX]}; done
##Example of how to iterate over the hostnames in the array
#for INDEX in $(seq 1 2 ${FINAL_AGENT_INDEX}); do echo ${ALL_AGENTS[INDEX]}; done


## Create the JeOS cluster nodes. Saves the state files to specific locations to keep things tidy
## Determine the CIDR denoted SUBNET based on the IP address of the first server
#SUBNET=$(getent hosts ${EDGE_LOCATION}-server-0 | awk '{print$1}' | awk -F. '{print$1"."$2"."$3".0/24"}')
SUBNET=$(echo ${ALL_SERVERS[0]} | awk -F. '{print$1"."$2"."$3".0/24"}')

## Create a custom tfvars file for this deployment
cat <<EOF> state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfvars
k3s_servers = ${NUM_SERVERS}
k3s_agents = ${NUM_AGENTS}
edge_location = "${EDGE_LOCATION}"
cidr_mapping = {${EDGE_LOCATION} = "${SUBNET}"}
EOF

terraform apply -auto-approve --state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate -var-file=terraform.tfvars -var-file=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfvars


mkdir -p ~/.kube/


## Ensure the server node is updated and ready before installing K3s 
ssh-keygen -q -R ${FIRST_SERVER_IP} -f ${HOME}/.ssh/known_hosts

## This tests for a shutdown entry to be added to the last log, indicating the node has rebooted
until ssh -o StrictHostKeyChecking=no opensuse@${FIRST_SERVER_IP} last -x | grep shutdown; do echo "Waiting for ${FIRST_SERVER_HOSTNAME} to boot up and update its software..." && sleep 30; done

## Test for sshd to come online after the reboot, then wait ten seconds more for the node to finish booting
until nc -zv ${FIRST_SERVER_IP} 22; do echo "Waiting until ${FIRST_SERVER_HOSTNAME} finishes rebooting..." && sleep 5; done
echo "Waiting for someone who truly gets me..."
sleep 10



## Remove a previous config file if it exists
rm -f ${HOME}/.kube/kubeconfig-${EDGE_LOCATION}


## Use k3sup to install the first server node
k3sup install --ip ${FIRST_SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable  --local-path ${HOME}/.kube/kubeconfig-${EDGE_LOCATION} --context k3s-${EDGE_LOCATION}



## Wait until the K3s server node is ready before joining the rest of the nodes
export KUBECONFIG=${HOME}/.kube/kubeconfig-${EDGE_LOCATION}
kubectl config set-context k3s-${EDGE_LOCATION}
sleep 5
kubectl -n kube-system wait --for=condition=available --timeout=600s deployment/coredns



###### Broken until a test that inserts --cluster is created
## Join the remaining two server nodes to the cluster
#for INDEX in 2 4; do 
#	k3sup join --ip ${ALL_SERVERS[INDEX]} --server --server-ip ${FIRST_SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable
#	sleep 5
#done
###### Broken until a test that inserts --cluster is created



## Join all agent nodes to the cluster
for INDEX in $(seq 0 2 ${FINAL_AGENT_INDEX}); do 
	k3sup join --ip ${ALL_AGENTS[INDEX]} --server-ip ${FIRST_SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable
	sleep 5
done



## Run the kubectl command to deploy the cattle-agent and fleet-agent
export KUBECONFIG=${HOME}/.kube/kubeconfig-${EDGE_LOCATION}
kubectl config use-context k3s-${EDGE_LOCATION}
bash -c "$(grep -w command ${PWD}/state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate | head -1 | awk -F\"command\"\: '{print$2}' | sed -e 's/",//' -e 's/"//')"

echo "export EDGE_LOCATION=${EDGE_LOCATION}; source ${HOME}/.rancher_tokens; terraform destroy -auto-approve --state=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfstate -var-file=terraform.tfvars -var-file=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfvars" > ./bin/destroy_${EDGE_LOCATION}_edge_location.sh

echo -e "######################## ${RED}TO DESTROY THIS CLUSTER, USE THE COMMAND:${LCYAN} ./bin/destroy_${EDGE_LOCATION}_edge_location.sh${NC} "
#echo -e "## ${LCYAN}export EDGE_LOCATION=${EDGE_LOCATION}; source ~/.rancher_tokens; terraform destroy -auto-approve --state=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfstate -var-file=terraform.tfvars -var-file=state/\${EDGE_LOCATION}/\${EDGE_LOCATION}.tfvars${NC}"
#echo "###########################################################################"
echo ""

chmod 755 ./bin/destroy_${EDGE_LOCATION}_edge_location.sh

echo ""; echo "It may take a few more minutes for the ${EDGE_LOCATION} cluster to finish getting ready for use."
echo ""; echo -e "Run the command sequence: \`${LCYAN}export EDGE_LOCATION=${EDGE_LOCATION}; export KUBECONFIG=${HOME}/.kube/kubeconfig-\${EDGE_LOCATION}; kubectl config set-context k3s-\${EDGE_LOCATION}${NC}\` to work with the k3s-${EDGE_LOCATION} cluster"
