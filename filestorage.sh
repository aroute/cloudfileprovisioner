#!/usr/bin/bash
##
# This script uses Google's NFS External Provisioner for Kubernetes. 
# Ref: https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner
# The provisioner script is for Red Hat OpenShift Container Platform managed by IBM Cloud.
# The script will request and create an order of a single storage device from IBM Cloud File service. 
# Ref: https://cloud.ibm.com/docs/FileStorage?topic=FileStorage-getting-started
# The request is of 1TiB File storage device (gold category). 
# The 1TiB is a hardcoded value. 
# DO NOT run this script if you wish to manipulate the pre-defined storage size.
# The script creates a StorageClass called 'cloudfilestorage'.
# This StorageClass is capable of RWX and RWO modes.
# Please ensure you are first logged in to your IBM Cloud account (ibmcloud login....)
# Ensure you are also logged in to your OpenShift cluster (oc login...)
# You will need to supply your cluster's ID, e.g,: ./filestorage.sh c1234abcd
# A typical use case: 
# You may want to deploy an OpenShift application with multiple PVCs all bound to a single File storage device.
##
set -e
##
if [ $# -eq 0 ]; then
  echo "$0: Supply ClusterID"
  exit 1
elif [ $# -gt 1 ]; then
  echo "$0: Something is wrong: $@"
  exit 1
else
##
git clone https://github.com/aroute/cloudfileprovisioner.git
cd cloudfileprovisioner
oc new-project filestorage
export NAMESPACE=`oc project -q`
oc create -f rbac.yaml
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner
##
export cluster=$1
##
export dc=$(ibmcloud oc cluster get --cluster ${cluster} --output json | jq -r '.dataCenter')
export region=$(ibmcloud oc cluster get --cluster ${cluster} --output json | jq -r '.region')
envsubst < filepvc.yaml | oc create -f -
while [[ $(oc get pvc cloudstorage -o 'jsonpath={..status.phase}') != "Bound" ]]; do echo "Awaiting the provisioning of the IBM Cloud File storage order." && sleep 1; done
##
export VOLNAME=$(oc get pvc cloudstorage -o jsonpath='{.spec.volumeName}')
export NFSSERVER=$(oc get pv "${VOLNAME}" -o jsonpath='{.spec.nfs.server}')
export NFSPATH=$(oc get pv "${VOLNAME}" -o jsonpath='{.spec.nfs.path}')
envsubst < provisioner.yaml | oc create -f -
while [[ $(oc get pods -l app=filestorage-provisioner -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for the filestorage-provisioner pod to be ready." && sleep 1; done
##
oc create -f storageclass.yaml
oc patch storageclass cloudfilestorage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
oc patch storageclass ibmc-block-gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
echo "Everything has been completed. The IBM Cloud File Storage device with a capacity of 1TiB is now ready, complete with the StorageClass of "cloudfilestorage"."
fi
