cat <<EOF> /tmp/${SERVICE_NAME}-tunnel.sh
#!/bin/bash
## Need to set ${SERVICE_NAME} ${APP_SERVER_IP} ${EC2_SSH_KEY_NAME} ${FRONT_END_IP} before running
while :
### Must ssh to the EC2 root user to open ports below 1000
do nohup ssh -p 2244 -R 0.0.0.0:42422:${APP_SERVER_IP}:22 -R 0.0.0.0:80:${APP_SERVER_IP}:80 -R 0.0.0.0:443:${APP_SERVER_IP}:443 -N -i /home/opensuse/.ssh/${EC2_SSH_KEY_NAME} root@${FRONT_END_IP}
### IMPORTANT: Before running, ssh to the EC2 instance root account (with sudo) to accept the sshd daemon's identity hash
sleep 10
done
EOF
