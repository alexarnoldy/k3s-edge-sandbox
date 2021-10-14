## This is the Internet facing URL, i.e. edge-demo.susealliances.com
export FRONT_URL="" 

## This will be the name of the service running on the back-end ssh tunnel server
export SERVICE_NAME="" 

## The IP address of the back-end ssh tunnel server
export BACK_END_IP="" 

## This key will bed used by the back-end ssh tunnel server to create the ssh tunnel to the front-end ec2 instance
export EC2_SSH_KEY_NAME=""

## The location of the EC2 instance's ssh key on this host (ideally in this directory)
export EC2_SSH_KEY_LOCATION=""

## This key will be used to ssh from this host to the back-end ssh tunnel server
export BACKEND_SSH_KEY_NAME=""

## The location of the back-end ssh tunnel server's ssh key on this host (ideally in this directory)
export BACKEND_SSH_KEY_LOCATION=""

## This is the user on the back-end ssh tunnel server
export SSH_USER=""

## The IP address or FQDN of the front-end ec2 instance
export FRONT_END_IP="" 

## The IP address of the server that runs the application that will be fronted with the FRONT_URL
export APP_SERVER_IP="" 

## (Optional) This is only applicable when Rancher 2.6 is the appliation to be provided on the Internet
export RANCHER_BOOTSTRAP_PW=""

