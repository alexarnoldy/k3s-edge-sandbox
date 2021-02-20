#!/bin/bash

## Script to run Terraform to create an openSUSE JeOS cluster on the local system then run K3sup to create a K3s cluster on it.
## 02/17/2021 - alex.arnoldy@suse.com

## Rancher tokens need to be kept in a file in the user's home directory
## Format needs to be:
## export RANCHER_ACCESS_KEY=token-xxxxx
## export RANCHER_SECRET_KEY=xxxxxxxxxxxxxxxx

source ${HOME}/.rancher_tokens

[ -z "$1" ] && echo "Usage: k3s-cluster-create.sh <name of predefined edge location>" && exit

EDGE_LOCATION=$1
SSH_USER="opensuse"

case ${EDGE_LOCATION} in
	bangkok) 
		SERVER_IP="10.111.1.11"
		AGENT_0_IP="10.111.1.14"
		AGENT_1_IP="10.111.1.15"
	;;
	freetown) 
		SERVER_IP="10.111.2.11"
		AGENT_0_IP="10.111.2.14"
		AGENT_1_IP="10.111.2.15"
	;;
	munich) 
		SERVER_IP="10.111.3.11"
		AGENT_0_IP="10.111.3.14"
		AGENT_1_IP="10.111.3.15"
	;;
	sydney) 
		SERVER_IP="10.111.4.11"
		AGENT_0_IP="10.111.4.14"
		AGENT_1_IP="10.111.4.15"
	;;
	*)
		echo "$1 Edge Location has not been defined. Exiting."
		exit
	;;
esac


## Create the JeOS cluster nodes. Saves the state files to specific locations to keep things tidy
terraform apply -auto-approve --state=state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate -var=edge_location=${EDGE_LOCATION}

mkdir -p ~/.kube/


## Ensure the server node is updated and ready before installing K3s 
ssh-keygen -q -R ${SERVER_IP} -f ${HOME}/.ssh/known_hosts
#echo "Waiting until server is updated..."
until ssh -o StrictHostKeyChecking=no opensuse@${SERVER_IP} which which; do echo "Waiting while ${SERVER_IP} updates its software..." && sleep 30; done
echo "Waiting for ${SERVER_IP} to reboot..."
sleep 60
until nc -zv ${SERVER_IP} 22; do echo "Waiting until ${SERVER_IP} finishes rebooting..." && sleep 5; done
echo "Waiting for someone who truly gets me..."
sleep 10



## Remove a previous config file, if it exists
rm -f ${HOME}/.kube/kubeconfig-${EDGE_LOCATION}


## Use k3sup to create the non-HA cluster removed ${MERGE} from install command
k3sup install --ip ${SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable  --local-path ${HOME}/.kube/kubeconfig-${EDGE_LOCATION} --context k3ai-${EDGE_LOCATION}



## Wait until the K3s server node is ready before joining agents
export KUBECONFIG=${HOME}/.kube/kubeconfig-${EDGE_LOCATION}
kubectl config set-context k3ai-${EDGE_LOCATION}
sleep 5
kubectl -n kube-system wait --for=condition=available --timeout=600s deployment/coredns

k3sup join --ip ${AGENT_0_IP} --server-ip ${SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable

k3sup join --ip ${AGENT_1_IP} --server-ip ${SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable



## Run the kubectl command to deploy the cattle-agent and fleet-agent
export KUBECONFIG=${HOME}/.kube/kubeconfig-${EDGE_LOCATION}
kubectl config use-context k3ai-${EDGE_LOCATION}
bash -c "$(grep -w command ~/k3ai-sandbox-demo/state/${EDGE_LOCATION}/${EDGE_LOCATION}.tfstate | head -1 | awk -F\"command\"\: '{print$2}' | sed -e 's/",//' -e 's/"//')"


echo ""; echo "Run the commands: \`export KUBECONFIG=${HOME}/.kube/kubeconfig-${EDGE_LOCATION}; kubectl config set-context k3ai-${EDGE_LOCATION}\` to work with the k3ai-${EDGE_LOCATION} cluster"
