#!/bin/bash

#######################################################################################################
#Script Name    : setup-cluster.sh
#Description    : Automates the generation of a k8s cluster with kubespray and hardens it according to 
#                 the CIS 1.5 Controls. This script also requires that it is sourced at runtime
#Args		: Configuration file w/ '-f file.config'
#######################################################################################################


#####
### These example config options can be copied from the kubesprayconfig.template 
### file in the root of the project.
#
# AWS_ACCESS_KEY_ID=XXXXXXXXXXX
# AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXX
# AWS_REGION=us-east-1
# CLUSTER_NAME=my.cluster.cloud
# KEY_PAIR_NAME=test-kp
# LOCAL_PEM_FILE=/home/user/.ssh/test-kp.pem
# KMS_ID=XXXXXXXXXXXX
#
### These values are optional and have default values
#
# AWS_ENCRYPTION_PROVIDER_IMAGE=test/image 
# MASTER_COUNT = 1 
# ETCD_COUNT = 1 
# WORKER_COUNT = 1 
# MASTER_SIZE = t3.medium 
# ETCD_SIZE = t3.medium 
# WORKER_SIZE = t3.medium 
#####



##### SETUP #####

# Making sure the file is sourced and parameters are appropriately used
(return 0 2>/dev/null) && SOURCED=1 || SOURCED=0
if [ "$SOURCED" == "0" ]; then
  usage
  exit
fi

# Since this script is being sourced, it is best to unset all utilized variables
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_REGION
unset CLUSTER_NAME
unset KEY_PAIR_NAME
unset LOCAL_PEM_FILE
unset KMS_ID
unset AWS_ENCRYPTION_PROVIDER_IMAGE
unset MASTER_COUNT
unset ETCD_COUNT
unset WORKER_COUNT
unset MASTER_SIZE
unset ETCD_SIZE
unset WORKER_SIZE


usage() {
   echo "Usage: "
   echo "Remember to source the script!"
    echo "  Options:"
    echo "      -f  <string> config file"
    echo "  Examples:"
    echo "      source setup-cluster -f ./kubesprayconfig"	
}

#
while getopts "f:" o; do
    case ${o} in
	f)
	    CONFIG_FILE=${OPTARG}
	    source $CONFIG_FILE
	    ;;
        h)
            usage
            exit 0
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done



if [ $# -ne 2 ]; then
  echo "Usage: -f [configuration file]"
  return
fi

if [ "$1" != "-f" ]; then
    echo "ERROR: Expecting -f parameter."
    return
fi



# Testing for a config file, then sourcing it
CONFIG_FILE=$2
if [ ! -f $CONFIG_FILE ]; then
    echo "ERROR: Missing configuration file: $CONFIG_FILE"
    return
fi
source $CONFIG_FILE


# And testing that all required variables are initialized to non-empty values
if [ -z $AWS_ACCESS_KEY_ID ]; then
  echo "ERROR: Missing environment variable: AWS_ACCESS_KEY_ID"
  return
fi
if [ -z $AWS_SECRET_ACCESS_KEY ]; then
  echo "ERROR: Missing environment variable: AWS_SECRET_ACCESS_KEY"
  return
fi
if [ -z $AWS_REGION ]; then
  echo "ERROR: Missing environment variable: AWS_REGION"
  return
fi
if [ -z $CLUSTER_NAME ]; then
  echo "ERROR: Missing environment variable: CLUSTER_NAME"
  return
fi
if [ -z $KEY_PAIR_NAME ]; then
  echo "ERROR: Missing environment variable: KEY_PAIR_NAME"
  return
fi
if [ -z $LOCAL_PEM_FILE ]; then
  echo "ERROR: Missing environment variable: LOCAL_PEM_FILE"
  return
fi
if [ -z $KMS_ID ]; then
  echo "ERROR: Missing environment variable: KMS_ID"
  return
fi


# Then tests for required prerequisites. A list of prereqs can be found in the repo README.
terraform --version > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "ERROR: Missing prerequisite: terraform"
  return
fi
ansible --version > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "ERROR: Missing prerequisite: ansible"
  return
fi
kubectl > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "ERROR: Missing prerequisite: kubectl"
  return
fi
python2 -m pip --version > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "ERROR: Missing prerequisite: python pip"
  return
fi
python2 -m pip install netaddr --upgrade > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "ERROR: Error updating prerequisite: python netaddr"
  return
fi
python2 -m pip install jinja2 --upgrade > /dev/null 2>&1
if [ $? != 0 ]; then
  echo "ERROR: Error updating prerequisite: python jinja2"
  return
fi


# Sets up default values for the optional config parameters
if [ -z $AWS_ENCRYPTION_PROVIDER_IMAGE ]; then
  AWS_ENCRYPTION_PROVIDER_IMAGE="da1ic1/aws-encryption-provider"
fi
if [ -z $MASTER_COUNT  ]; then
  MASTER_COUNT=1
fi
if [ -z $MASTER_SIZE ]; then
  MASTER_SIZE="t3.medium"
fi
if [ -z $ETCD_COUNT ]; then
  ETCD_COUNT=1
fi
if [ -z $ETCD_SIZE ]; then
  ETCD_SIZE="t3.medium"
fi
if [ -z $WORKER_COUNT ]; then
  WORKER_COUNT=1
fi
if [ -z $WORKER_SIZE ]; then
  WORKER_SIZE="t3.medium"
fi


# Pulls KMS key's ARN from AWS for setup of encryption at rest using the KMS key ID
AWS_KEY_ARN=$(aws kms describe-key --key-id $KMS_ID --query KeyMetadata.Arn --output text --region $AWS_REGION)
if [ $? != 0 ] || [ -z "$AWS_KEY_ARN" ]; then
  echo "Error grabbing KMS key's ARN with given KMS Key ID, is the key ID correct?"
  return
fi  


##### Installation #####


# Terraform is used to create the infrastructure that k8s will be installed on
cd contrib/terraform/aws/

terraform init
if [ $? != 0 ]; then 
  echo "terraform init failed. Check the logs or run 'terraform init' for more details"
  return 
fi

terraform apply \
	-var="aws_cluster_name=$CLUSTER_NAME" \
	-var="AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
	-var="AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
	-var="AWS_SSH_KEY_NAME=$KEY_PAIR_NAME" \
	-var="AWS_DEFAULT_REGION=$AWS_REGION" \
	-var="aws_kube_master_num=$MASTER_COUNT" \
	-var="aws_kube_master_size=$MASTER_SIZE" \
	-var="aws_etcd_num=$ETCD_COUNT" \
	-var="aws_etcd_size=$ETCD_SIZE" \
	-var="aws_kube_worker_num=$WORKER_COUNT" \
	-var="aws_kube_worker_size=$WORKER_SIZE" \
	--auto-approve 
if [ $? != 0 ]; then
  echo "terraform apply failed. Check the preceeding output and make sure the config file is correct"
  return
fi

# Installs k8s once the AWS resources are created
cd ../../..

time ansible-playbook \
  -i ./inventory/hosts \
  ./cluster.yml \
  -e ansible_user=centos \
  -e cloud_provider=aws \
  -e bootstrap_os=centos \
  --become \
  --become-user=root \
  --flush-cache \
  -e ansible_ssh_private_key_file=$LOCAL_PEM_FILE
if [ $? != 0 ]; then
  echo "Anisble-playbook failed. Check the preceeding output for more information"
  return
fi

# Sourcing a file that extracts ips of cluster devices to simplify ssh
VARFILE=clusterssh.vars
if [ ! -f $VARFILE ]; then
  echo "$VARFILE doesn't exist, was it moved or deleted?"
  return
fi
source $VARFILE


# Some changes to allow kubectl commands from the ansible host to connect to the cluster
mkdir -p ~/.kube
ERR1=$?
ssh -o 'StrictHostKeyChecking no' -F ssh-bastion.conf \
	centos@$CONTROLLER_IP "sudo chmod 644 /etc/kubernetes/admin.conf"
ERR2=$?
scp -o 'StrictHostKeyChecking no' -F ssh-bastion.conf \
	centos@$CONTROLLER_IP:/etc/kubernetes/admin.conf ~/.kube/config
ERR3=$?
sed -i "s^server:.*^server: https://$LB_HOST:6443^" ~/.kube/config
ERR4=$?
if [ $ERR1 != 0 ] || [ $ERR2 != 0 ] || [ $ERR3 != 0 ] || [ $ERR4 != 0 ]; then
  echo "Configurating local kubectl to connect to cluster failed, try running configkubectl.sh after."
  echo "If the script fails, then there may be an issue with kubectl or connecting to the cluster."
  sleep 10
fi


##### Post-Install Configuration #####


# Download and apply RBAC policies for PodSecurityPolicy configuration
kubectl apply -f rbac-for-pod-security-policies.yaml
if [ $? != 0 ]; then
  echo "Apply failed, PodSecurityPolicy will not be configured!" 
  sleep 10
fi

# Ansible script to configure encryption at rest configuration on the cluster
time ansible-playbook \
  -i ./inventory/hosts \
  ./psp-kms-install.yaml \
  -e ansible_user=centos \
  -e cloud_provider=aws \
  -e bootstrap_os=centos \
  -e AWS_ENCRYPTION_PROVIDER_IMAGE=$AWS_ENCRYPTION_PROVIDER_IMAGE \
  -e AWS_KEY_ARN=$AWS_KEY_ARN \
  -e AWS_REGION=$AWS_REGION \
  --become \
  --become-user=root \
  --flush-cache \
  -e ansible_ssh_private_key_file=$LOCAL_PEM_FILE
if [ $? != 0 ]; then
  echo "Ansible configuration of PodSecurityPolicy and Encryption at Rest with KMS failed, they may not be configured!"
  sleep 10
fi

# Ansible script to configure hardening for CIS 1.5 Remediations that are still open
time ansible-playbook \
  -i ./inventory/hosts \
  ./post-install-cis-remediation.yaml \
  -e ansible_user=centos \
  -e cloud_provider=aws \
  -e bootstrap_os=centos \
  --become \
  --become-user=root \
  --flush-cache \
  -e ansible_ssh_private_key_file=$LOCAL_PEM_FILE
if [ $? != 0 ]; then
  echo "Ansible fix for CIS 1.5 Remediations failed! The system is most likely not hardened completely!" 
  sleep 10
fi

# Final check to see if we can access k8s.
echo "Checking kubectl access to nodes..."
sleep 10
kubectl get nodes
