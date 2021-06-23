# URL of the libvirt server
# EXAMPLE:
libvirt_uri = "qemu:///system"
#libvirt_uri = ""

# Path of the key file used to connect to the libvirt server
# Note this value will be appended to the libvirt_uri as a 'keyfile' query: <libvirt_uri>?keyfile=<libvirt_keyfile>
# EXAMPLE:
# libvirt_keyfile = "~/.ssh/custom_id"
#libvirt_keyfile = ""

# URL of the image to use
# EXAMPLE:
# image_uri = "http://download.suse.com/..."
image_uri = "images/openSUSE-Leap-15.2-JeOS.x86_64-15.2-patched-03232021.qcow2"
#image_uri = "images/openSUSE-Leap-15.2-JeOS.x86_64-15.2-OpenStack-Cloud-Build31.348.qcow2"

# Identifier to make all your resources unique and avoid clashes with other users of this terraform project
## Set edge_location with the bin/k3s_create_cluster.sh script
#edge_location = "k3s-sandbox-demo"

# Number of server nodes
## k3s_servers is based on entries in /etc/hosts or DNS
## server_memory and server_vcpu can be overriden with entries in /etc/hosts, if used
#k3s_servers       = 1
server_memory = 2048
server_vcpu   = 2

# Number of agent nodes
## Set k3s_agents with the bin/k3s_create_cluster.sh script
## agent_memory and agent_vcpu can be overriden with entries in /etc/hosts, if used
#k3s_agents       = 2
agent_memory = 2048
agent_vcpu   = 2

# Username for the cluster nodes
# EXAMPLE:
#username = "opensuse"

# Password for the cluster nodes
# EXAMPLE:
#password = "SUSE-linux"

# Minimum required packages. Do not remove them.
# Feel free to add more packages
#packages = [
#  "kernel-default",
#  "-kernel-default-base"
#]

# SSH keys to be injected into the cluster nodes. If deploying an admin node, should include the key from that node.
# EXAMPLE:
# authorized_keys = [
#  "ssh-rsa <key1-content>",
#  "ssh-rsa <key2-content>"
# ]
authorized_keys = [
"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1PluS3uR9V5xoT69/102mJJnzaL+FzyvmU+8QXIjhn2JC+n+OaKlQ05n7faEcNS+Ebv2Q1nUYthA7jVLZv/V8PCPg65JUQj2ALw+IM4J9wuIHanTkK7yknpF5ThjAz6HSF11rEVcpm/9vzSWKXOzTM/ucKbTiyRbps1HgozNYJtqXVaVpO1moPZ24xHbsdTfTzU98cpwxMRFVj5MBRm/GvnmXB5u5QJjTJOe6DdxNE3qwJCckYjJ9rTIjJzSl9NwGtH9+3kuBz8SPxHbKplDC517M0Ag99G9bqGoHpgyETRf32a4hvDVsWMlnCEWG4+RtABCgwsIeEZqc5JiSYRQZnIV2jrN7CJ4t8sugplgyIVBtCk1MJC20/lXOPXTk49T9x2wLRuKHShZo459aT44xSOVN1MD6O1luwx846o9Q28qEyqJWnFLkrDpPG2y1iVbvte63G6HagvcZQeEFCYQf+wWWM9Q5pr+gKt+iY6NOFZKkqlB+WOmvdfZKD/iUtwU= sles@k3ai-host-1"
]

# IMPORTANT: Replace these ntp servers with ones from your infrastructure
#ntp_servers = []
