At the moment, this draft is mostly the [kubespray repo](https://github.com/kubernetes-sigs/kubespray) with several key changes done for this project.

The changes include:
  * _/contrib/terraform/aws/variables.tf_ has been changed to use Centos AMI's instead of amazon linux
  * The cluster size has been decreased so there is 1 of each type of node
  * Changes necessary for encryption at rest have been pre-set into the _contrib/terraform/aws/modules/iam/main.tf_ file
  * ssh-to scripts are already set and can be used once the terraform and ansible steps are complete to ssh to the different nodes
  * post-install-cis-remediations.yaml file is included in root folder along with new remediation roles in the roles folder to complete cis checklist
  * setup-cluster.sh and restart-cluster.sh script files to automate the install as well as template for script config file needed
  * setkubevars file to source needed vars quickly (IPs of machines, not ready for multi-node clusters)
  
  Prerequisites
  * Git
  * Terraform
  * Ansible
  * Kubectl
  * Python pip module
  
  Steps
  1. Clone Project (git clone https://github.com/department-of-veterans-affairs/va-kubernetes-cis-benchmarked.git)
  
  2. Create kubespray config file needed for automation (use kubesprayconfig.template)
  
  3. source setup-cluster.sh as well as giving it the config file (source setup-cluster.sh -f kubesprayconfig)
  
  
  
  
  
The automation script was created using [these instructions by David Medinets](https://medined.github.io/centos/terraform/ansible/kubernetes/kubespray/provision-centos-kubernetes-cluster-on-aws/)
  
