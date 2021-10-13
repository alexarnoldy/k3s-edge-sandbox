## This is the Internet facing URL, i.e. edge-demo.susealliances.com
export FRONT_URL="" 

## This will be the name of the service running on the back-end ssh tunnel server
export SERVICE_NAME="" 

## The IP address of the back-end ssh tunnel server
export BACK_END_IP="" 

## The back-end ssh tunnel server needs the ssh key to create the ssh tunnel to the front-end ec2 instance
export EC2_SSH_KEY_NAME=""

## The location of the ssh key on this host (ideally in this directory)
export EC2_SSH_KEY_LOCATION=""

## This is the user on the back-end ssh tunnel server
export SSH_USER=""

## The IP address or FQDN of the front-end ec2 instance
export FRONT_END_IP="" 

## The IP address of the server that runs the application that will be fronted with the FRONT_URL
export APP_SERVER_IP="" 

## This is only applicable to Rancher 2.6 apps, and specifically for the docker container version
export RANCHER_BOOTSTRAP_PW=""

