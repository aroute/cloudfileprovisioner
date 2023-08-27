# IBM Cloud File Storage Provisioner - Automatic process

See `./filestorage.sh`.

# IBM Cloud File Storage Provisioner - Manual process

This NFS cloud file provisioner for OpenShift will help in conserving the number of Cloud File storage devices it takes to deploy Cloud Pak for Data. Instead of auto-provisioning multiple File devices for individual PVCs, you can use this provisioner to provision one big device and then use the storageclass to provision multiple PVCs.

1. Create a new project and apply RBAC.
```shell
oc new-project filestorage
```
```shell
NAMESPACE=`oc project -q`
```
```shell
oc create -f rbac.yaml
```
```shell
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:$NAMESPACE:nfs-client-provisioner
```

2. Identify your Cluster, Data Center and the Region.
```shell
export cluster=<your cluster ID>
```
```shell
export dc=$(ibmcloud oc cluster get --cluster ${cluster} --output json | jq -r '.dataCenter')
```
```shell
export region=$(ibmcloud oc cluster get --cluster ${cluster} --output json | jq -r '.region')
```

3. Place an order for a new File storage device (default is 1TB disk space. Change it if you require more).
```shell
envsubst < filepvc.yaml | oc create -f -
```

⏰ Wait a minute or two to let the provisioner allocate a new device.

4. After PV is provisioned, export needed values as variables.
```shell
oc get pvc
```
```shell
export VOLNAME=$(oc get pvc cloudstorage -o jsonpath='{.spec.volumeName}')
```
```shell
export NFSSERVER=$(oc get pv "${VOLNAME}" -o jsonpath='{.spec.nfs.server}')
```
```shell
export NFSPATH=$(oc get pv "${VOLNAME}" -o jsonpath='{.spec.nfs.path}')
```

5. Deploy the provisioner.
```shell
envsubst < provisioner.yaml | oc create -f -
```

⏰ Wait a minute or two for the pod to come up: `oc get pods`

6. Create a new StorageClass called `cloudfilestorage` and make it a default.
```shell
oc create -f storageclass.yaml
```
```shell
oc patch storageclass cloudfilestorage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
```shell
oc patch storageclass ibmc-block-gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

7. (optional) Test by creating a claim and a pod.
```shell
oc create -f testclaim.yaml
```
```shell
oc create -f testpod.yaml
```





