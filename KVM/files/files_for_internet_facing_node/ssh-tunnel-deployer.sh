#!/bin/bash

## Script to set up an ssh tunnel between an EC2 instance and an application running in a local network
## 
## Before running this script:
## 1. Create an EC2 instance with an EIP and a FQDN in Route 53
## 2. Set the EC2 instance's ssh port to 2244 and set `GatewayPorts clientspecified` in /etc/ssh/sshd_config 
## 3. Restart sshd.service
## 4. Place the ssh key on this host (ideally in this directory)
## 5. Set the variables in the variables.sh file
##
## With those steps completed, run this script 

ssh ${SSH_USER}@${BACK_END_IP} 'bash -s' << EOF
echo "[Unit]
Description=Maintain an SSH tunnel for ${SERVICE_NAME} access to lab
[Service]
Restart=always
ExecStart=/bin/bash /usr/local/bin/${SERVICE_NAME}-tunnel.sh
[Install]
WantedBy=multi-user.target" > /tmp/${SERVICE_NAME}-tunnel.service
EOF

ssh ${SSH_USER}@${BACK_END_IP} mkdir -p .ssh
scp ${EC2_SSH_KEY_LOCATION} ${SSH_USER}@${BACK_END_IP}:.ssh/${EC2_SSH_KEY_NAME}
ssh ${SSH_USER}@${BACK_END_IP} chmod 400 .ssh/${EC2_SSH_KEY_NAME}

### Insert a read statement, then ssh statement with instructions
## Need to ssh from the back end server to the EC2 instance to remove the script in the root authorized_hosts as well as accept the EC2 key, again ssh'ing as the root user to the EC2 root user
### Script continues after exiting the ssh session

ssh ${SSH_USER}@${BACK_END_IP} 'bash -s' << EOF
echo "#!/bin/bash
## Need to set ${SERVICE_NAME} ${APP_SERVER_IP} ${EC2_SSH_KEY_NAME} ${FRONT_END_IP} before running
while :
do nohup ssh -p 2244 -R 0.0.0.0:42422:${APP_SERVER_IP}:22 -R 0.0.0.0:80:${APP_SERVER_IP}:80 -R 0.0.0.0:443:${APP_SERVER_IP}:443 -N -i /home/${SSH_USER}/.ssh/${EC2_SSH_KEY_NAME} ec2-user@${FRONT_END_IP}
sleep 10
done" > /tmp/${SERVICE_NAME}-tunnel.sh
EOF

ssh ${SSH_USER}@${BACK_END_IP} <<EOF
sudo mv /tmp/${SERVICE_NAME}-tunnel.service /etc/systemd/system/
sudo mv /tmp/${SERVICE_NAME}-tunnel.sh /usr/local/bin/
sudo systemctl enable --now ${SERVICE_NAME}-tunnel.service
EOF

## To install Rancher server as the application:
ssh ${SSH_USER}@${APP_SERVER_IP} << EOF
sudo zypper -n in docker
sudo systemctl enable --now docker.service
sudo usermod -aG docker ${SSH_USER}
EOF
ssh ${SSH_USER}@${APP_SERVER_IP} docker ps -a

ssh ${SSH_USER}@${APP_SERVER_IP} << EOF
docker run \
	--detach \
	--restart=unless-stopped \
	--publish 80:80 --publish 443:443 \
	--privileged \
  --name rancher \
  -e CATTLE_BOOTSTRAP_PASSWORD=${RANCHER_BOOTSTRAP_PW} \
  rancher/rancher --acme-domain ${FRONT_URL}
EOF



