#!/bin/bash

cd contrib/terraform/aws/
source ../../../kubesprayconfig

time terraform destroy \
	-var="aws_cluster_name=$CLUSTER_NAME" \
	-var="AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
	-var="AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
	-var="AWS_SSH_KEY_NAME=$KEY_PAIR_NAME" \
	-var="AWS_DEFAULT_REGION=$AWS_REGION" \
	--auto-approve

rm ../../../inventory/hosts ../../../ssh-bastion.conf > /dev/null 2>&1

source ../../../setup-cluster.sh -f ../../../kubesprayconfig
