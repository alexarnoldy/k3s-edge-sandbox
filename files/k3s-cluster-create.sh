#!/bin/bash

## Script to run Terraform to create an openSUSE JeOS cluster on the local system then run K3sup to create a K3s cluster on it.
## 02/17/2021 - alex.arnoldy@suse.com

[ -z "$1" ] && echo "Usage: k3s-cluster-create.sh <name of cluster, from prefined list>" && exit

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
esac

mkdir -p ~/.kube/

## Need to set the --merge flag only after the ~/.kube/config file has been created by the first cluster creation
[ -f ~/.kube/config ] && MERGE="--merge" || MERGE=""

until ssh opensuse@${SERVER_IP} which which; do echo "waiting for ${SERVER_IP}" && sleep 5; done
sleep 60
until nc -zv ${SERVER_IP} 22; do echo "waiting for ${SERVER_IP}" && sleep 5; done
sleep 10

## Use k3sup to create the non-HA cluster 
k3sup install --ip ${SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable ${MERGE} --local-path ${HOME}/.kube/config --context k3ai-${EDGE_LOCATION}

## Wait until the K3s server node is ready before joining agents
export KUBECONFIG=/home/sles/.kube/config
kubectl config set-context k3ai-${EDGE_LOCATION}
sleep 5
kubectl -n kube-system wait --for=condition=available --timeout=600s deployment/coredns
#sleep 10
#read -i "press enter when ready to continue"
#kubectl -n kube-system wait --for=condition=available --timeout=600s deployment/traefik

k3sup join --ip ${AGENT_0_IP} --server-ip ${SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable

k3sup join --ip ${AGENT_1_IP} --server-ip ${SERVER_IP} --sudo --user ${SSH_USER} --k3s-channel stable

