## :trident: Prework - Get LoD Ready

For this Hands-on Workshop, we are going to use Lab on Demand. Please enroll yourself the following Lab:
https://labondemand.netapp.com/node/878

First a big thank you to [Yves Weisser](github.com/yvosonthehub) as his LabNetApp repository is the foundation of this training material. I highly recommend to have look at his work and redo this from time to time as he is doing a tremendous job, explaining all the Trident functionalities with real good examples. 

**The Lab guide is only needed for getting the usernames and passwords. Please ignore the tasks in the lab guide, everything you need is in this github repository.**

Access the host *rhel3* via putty and clone this github repo

```console
git clone https://github.com/ntap-johanneswagner/tridentusertraining
```

After that, jump into the directory, and run the prework script This script will prepare the lab for our excercises.

```console
cd /root/tridentusertraining/
./prework.sh
```

This will take some minutes...

## :trident: Scenario 01 - Configure Trident
**Remember: All required files are in the folder */root/tridentusertraining/scenario01* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridentusertraining/scenario01
```
Installation is quiet easy and straight forward, the fun begins with the configuration. 

### Backends

Via a TridentBackend, we are telling Trident how to contact the storagesystem and which driver to use. There are two ways to create Backends. 1. via tridentctl, 2. via a TridentBackenConfiguration CRD in K8s. The second way is the most common today, so we use it for our excercise. If you want to find out how to do it with tridentctl, have a look at the documentation: https://docs.netapp.com/us-en/trident/trident-use/backend_ops_tridentctl.html#create-a-backend

You will see different example configurations in the folder, to cover the different drivers. 

backend-ontap-nas.yaml is an example for using the ontap-nas driver.  
backend-ontap-nas-eco.yaml is an example for using the ontap-nas-economy driver.  
backend-ontap-san.yaml is an example for using the ontap-san driver using iSCSI.  
backend-ontap-san-eco.yaml is an example for using the ontap-san-economy driver using iSCSI.  

Edit each of them using your favorite editor and insert the missing values. Please use the SVM "labsvm" for this tasks as the nassvm and sansvm is a leftover from the original lab.
Small hint: To find out the network of your k8s nodes, *kubectl get nodes -o wide* might be helpful. 

You might have noticed that there is a reference to the credentials, called secret-svm. To provide Trident the necessary credentials to login into the svm, there are different possibilities. Trident supports local users, certificates and LDAP users. In most of the cases local users are used, so we do here.

Edit the secret-svm.yaml file and fill in user and password (Hint for getting the password of the trident user if you don't want to reset it: Look into the ansible playbook at labsvm.yaml). You will also see that there are values for the chap configuration provided. As we specified *useChap: true* in the backends, we need to tell Trident these values as Trident will do this configuration at the SVM. 

After you edited all the files, apply them to your k8s cluster:

```console
kubectl apply -f secret-svm.yaml
kubectl apply -f backend-ontap-nas.yaml
kubectl apply -f backend-ontap-nas-eco.yaml
kubectl apply -f backend-ontap-san.yaml
kubectl apply -f backend-ontap-san-eco.yaml 
```

As soon as they are applied, you can check the status of them via *kubectl get tbc -n trident*

The output should look like this:

```console
kubectl get tbc -n trident
‌kubectl get tbc -n trident
NAME                        BACKEND NAME   BACKEND UUID                           PHASE   STATUS
backend-ontap-nas           nas            1e4ff09a-b0ce-4709-8797-908139addd3f   Bound   Success
backend-ontap-nas-economy   nas-economy    ecccd445-93dd-4c0b-a8c3-8e7955654620   Bound   Success
backend-ontap-san           san            6a5068b5-24f1-4bc0-8376-babc438425ba   Bound   Success
backend-ontap-san-economy   san-economy    5eb0274f-ffe6-460e-a83b-54a87f29c9b1   Bound   Success
```

If everything is bound, all good. If the status is different to bound, inspect it via *kubectl describe tbc `<tbcname>` -n `<trident-namespace>`* find the errors and fix them. 

### StorageClass

The second thing we need to get Trident working, is a StorageClass that refers the PVC towards Trident.

In the folder you will find also some prepared files.

sc-nas.yaml is the StorageClass definition for the ontap-nas driver.  
sc-nas-eco.yaml is the StorageClass definition for the ontap-nas-economy driver.  
sc-san.yaml is the StorageClass definition for the ontap-san driver.  
sc-san-eco.yaml is the StorageClass definition for the ontap-nas-economy driver.

Have a quick look at them, this time there is no need for edits, and apply them:

```console
kubectl apply -f sc-nas.yaml
kubectl apply -f sc-nas-eco.yaml
kubectl apply -f sc-san.yaml
kubectl apply -f sc-san-eco.yaml 
```

Check the status with *kubectl get sc*

```console
kubectl get sc

NAME               PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-nas (default)   csi.trident.netapp.io   Delete          Immediate           true                   29s
sc-nas-eco         csi.trident.netapp.io   Delete          Immediate           true                   29s
sc-san             csi.trident.netapp.io   Delete          Immediate           true                   29s
sc-san-eco         csi.trident.netapp.io   Delete          Immediate           true                   10s
```

### VolumeSnapshotClass

While having backend and storageclass configured is enough to provide persistent storage, sooner or later there might be the need for doing so called CSI-Snapshots. For this a few other things are needed. 
First the snapshot controller needs to be installed/ enabled on the cluster. This should be the case in most of the modern distributions, however it happens still that its missing. If you want to have more details on how to install it, this link is a good read: https://github.com/kubernetes-csi/external-snapshotter
In our cluster, it's already installed, let's check this:  

```console
kubectl get crd | grep volumesnapshot
volumesnapshotclasses.snapshot.storage.k8s.io         2024-04-27T21:06:08Z
volumesnapshotcontents.snapshot.storage.k8s.io        2024-04-27T21:06:08Z
volumesnapshots.snapshot.storage.k8s.io               2024-04-27T21:06:08Z

kubectl get all -n kube-system -l app=snapshot-controller
NAME                                       READY   STATUS    RESTARTS   AGE
pod/snapshot-controller-54f7648f78-lvgp2   1/1     Running   6          93d
pod/snapshot-controller-54f7648f78-p9gvk   1/1     Running   6          93d

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/snapshot-controller-54f7648f78   2         2         2       93d
```

Aside from the 3 CRD & the Controller StatefulSet, the following objects have also been created during the installation of the CSI Snapshot feature:  
- serviceaccount/snapshot-controller
- clusterrole.rbac.authorization.k8s.io/snapshot-controller-runner
- clusterrolebinding.rbac.authorization.k8s.io/snapshot-controller-role
- role.rbac.authorization.k8s.io/snapshot-controller-leaderelection
- rolebinding.rbac.authorization.k8s.io/snapshot-controller-leaderelection

This base is needed for every CSI-driver that needs CSI-snapshots the next what is needed is a so called VolumeSnapshotClass that tells k8s to address the csi driver for the snapshot. The necessary file is already in your folder, have a look at it and apply it afterwards.

```console
kubectl apply -f volumesnapshotclass.yaml
```

## :trident: Scenario 02 - Testing Trident with the first applications
**Remember: All required files are in the folder */root/tridentusertraining/scenario02* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridentusertraining/scenario02
```

It's quiet important to understand that even if Trident creates Volumes successful and you can see the PVC/PV objects created in K8s, there is still a ton of things that can go wrong. To verfiy that installation and configuration is successful, it's important to run some kind of test application to verify that also the worker nodes were correctly prepared. 

There are 5 files in the folder. One will create a pod that has 4 PVCs, one for each storage class. The others have only one covering one sc. 

Apply them and have a look whether all works or if something fails. 

```console
kubectl get pods,pvc -n allstorageclasses
kubectl get pods,pvc -n nasapp
kubectl get pods,pvc -n nasecoapp
kubectl get pods,pvc -n sanapp
kubectl get pods,pvc -n sanecoapp
```

If there are errors or things stuck in pending, the first you should do is to have a look by using kubectl describe. Possible objects to start: Pod, PVC, trident controller.

Also let's try out whether we really can write data and read it again:

```console
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!" > /nas/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas-economy driver!" > /naseco/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san driver!" > /san/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san-economy driver!" > /saneco/test.txt'
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!" > /nas/test.txt'
kubectl exec -n nasecoapp $(kubectl get pod -n nasecoapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas-economy driver!" > /naseco/test.txt'
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san driver!" > /san/test.txt'
kubectl exec -n sanecoapp $(kubectl get pod -n sanecoapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san-economy driver!" > /saneco/test.txt'

```


```console
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /nas/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /naseco/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /san/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /saneco/test.txt
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
kubectl exec -n nasecoapp $(kubectl get pod -n nasecoapp -o name) -- more /naseco/test.txt
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- more /san/test.txt
kubectl exec -n sanecoapp $(kubectl get pod -n sanecoapp -o name) -- more /saneco/test.txt
```

## :trident: Scenario 03 - Backup anyone? Installation of Trident protect
**Remember: All required files are in the folder */root/tridentusertraining/scenario03* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridentusertraining/scenario04
```

As K8s based applications become more and more important, people ask the mean questions around backup, dr and so on.

Since October 2024, Trident has a small add-on, called Trident protect. This little application is meant to do k8s native backup & DR.

We do this again utilizing a private registry. To access it we need a secret again, lets creat this first:

```console
kubectl create ns trident-protect
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com
```

We are going to use parameters gathered in the trident_protect_helm_values.yaml file.
Now we can add the helm repository and install trident protect:

```console
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/
helm registry login registry.demo.netapp.com -u registryuser -p Netapp1!

helm install trident-protect netapp-trident-protect/trident-protect --set clusterName=lod1 --version 100.2506.0 --namespace trident-protect -f trident_protect_helm_values.yaml
```

After a very short time you should be able to see Trident protect being installed successfully. 
```console
kubectl get pods -n trident-protect
NAME                                                           READY   STATUS    RESTARTS   AGE
trident-protect-controller-manager-6454f4776f-6ls7v            2/2     Running   0          1h
```

Trident Protect CR can be configured with YAML manifests or CLI.  
Let's install its CLI which avoids making mistakes when creating the YAML files:  
```console
cd
curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/25.06.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin

curl -L -O https://github.com/NetApp/tridentctl-protect/releases/download/25.02.0/tridentctl-completion.bash
mkdir -p ~/.bash/completions
mv tridentctl-completion.bash ~/.bash/completions/
source ~/.bash/completions/tridentctl-completion.bash

cat <<EOT >> ~/.bashrc
source ~/.bash/completions/tridentctl-completion.bash
EOT
```

The CLI will appear as a new sub-menu in the _tridentctl_ tool.  
```console
tridentctl-protect version
25.06.0
```

## :trident: Scenario 04 - Trident protect initial configuration

There are not many "administrative" tasks when it comes to Trident protect. It's installation (what we've done in Scenario04) and creating the AppVaults.

An AppVault is our backup target, or said differently the single source of truth when it comes to restores. We can loose everything, as long as we still have the AppVault we can start restores, even if the whole K8s Cluster and the original storage system was destroyed completely.

Several applications can share the same bucket, through the same AppVault.  
If you have only one bucket available (like in this lab), one AppVault per Trident Protect is enough.  

Let's see how we can create an AppVault in the lab.  
We first need to retrieve the bucket _access key_ & _secret_.  

During the prework, a s3-svm was created already. In the output file (/root/tridentusertraining/ansible_S3_SVM_result.txt) of the ansible-playbook you should be able to find the key. 
```text
TASK [Print ONTAP Response for S3 User create] *********************************
ok: [localhost] => {
    "msg": [
        "SAVE THESE credentials for: S3user",
        "user access_key: EO1XP61T31I8EDGUZ1PM ",
        "user secret_key: SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx "
    ]
}
```
If you don't have this file at hand, you can connect to ONTAP in cli and retrieve the keys in advanced mode:  
```console
cluster1::> set -priv advanced

cluster1::*> vserver object-store-server user show -vserver svm_s3
Vserver     User            ID       Key Time To Live Key Expiry Time
----------- --------------- -------- ---------------- -----------------
svm_s3      root            0        -                -
Access Key: -
Secret Key: -
   Comment: Root User
svm_s3      S3user          1        -                -
Access Key: EO1XP61T31I8EDGUZ1PM
Secret Key: SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx
   Comment:
2 entries were displayed.
```

Now that you know where to retrieve those keys, let's create variables that we will use a few times:  
```console
BUCKETKEY=<youraccesskey>
BUCKETSECRET=<yoursecretkey>
```
Creating an AppVault requires a secret where the keys are stored:  
```console
kubectl create secret generic -n trident-protect s3-creds --from-literal=accessKeyID=$BUCKETKEY --from-literal=secretAccessKey=$BUCKETSECRET
```
You can now proceed with the AppVault creation & validation (_on both Kubernetes clusters_):  
```console
tridentctl-protect create appvault OntapS3 ontap-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect
```
Verify the creation:
```console
tridentctl-protect get appvault -n trident-protect
```
```console
+--------------+----------+-----------+------+-------+
|     NAME     | PROVIDER |   STATE   | AGE  | ERROR |
+--------------+----------+-----------+------+-------+
|  ontap-vault | OntapS3  | Available |   3h |       |
+--------------+----------+-----------+------+-------+
```
If the bucket is listed as _available_, then the process was successful.  

You can also install a S3 browser, which can be quite useful.  
I tend to often use the one provided by AWS, which can be quite handy:  
```console
cd
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws

mkdir ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $BUCKETKEY
aws_secret_access_key = $BUCKETSECRET
EOF
```

2 commands that could be useful to list the content of the bucket:  
```console
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod --summarize
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod --recursive --summarize
```
## :trident: Scenario 06 - Protecting an application

Note: As mentioned above, Trident protect CRs can be configured as yaml manifests or via tridentctl-protect. I recommend to have a look at these two blog articles where the typical procedures are shown utilizing both ways.  
[General Workflows, yaml manifests](https://community.netapp.com/t5/Tech-ONTAP-Blogs/Kubernetes-driven-data-management-The-new-era-with-Trident-protect/ba-p/456395)  
[General Workflows, cli extension](https://community.netapp.com/t5/Tech-ONTAP-Blogs/Introducing-tridentctl-protect-the-powerful-CLI-for-Trident-protect/ba-p/456494)

To keep it simple, we will work with tridentctl-protect in this scenario. 
## A. App creation 
The first step is to tell Trident protect what is our application. We will use the example app we used for testing the ontap-nas driver.

```console
tridentctl-protect create app nasapp --namespaces 'nasapp(app=busybox)' -n nasapp
```
You can verify the status with the following command:
```console
tridentctl-protect get app -n nasapp
```
If everything is successfull it should look like this:
```console
+--------+------------+-------+-----+
|  NAME  | NAMESPACES | STATE | AGE |
+--------+------------+-------+-----+
| nasapp | nasapp     | Ready | 9s  |
+--------+------------+-------+-----+
```

## B. Snapshot creation  
Creating an app snapshot consists in 2 steps:  
- create a CSI snapshot per PVC  
- copy the app metadata in the AppVault  
This is potentially done in conjunction with _hooks_ in order to interact with the app. This part is not covered in this chapter.  

Let's create a snapshot:  
```console
tridentctl-protect create snapshot nasappsnap --app nasapp --appvault ontap-vault -n nasapp
```

We can list now the Snapshot  

```console
tridentctl-protect get snap -n nasapp
```

```console
+------------+--------+----------------+-----------+-------+-----+
|    NAME    |  APP   | RECLAIM POLICY |   STATE   | ERROR | AGE |
+------------+--------+----------------+-----------+-------+-----+
| nasappsnap | nasapp | Delete         | Completed |       | 10s |
+------------+--------+----------------+-----------+-------+-----+
```

As our app has 1 PVC, you should find 1 Volume Snapshots:  
```console
kubectl get vs -n nasapp
```
```console
‌NAME                                                                                     READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS    SNAPSHOTCONTENT                                    CREATIONTIME   AGE
snapshot-32120d0a-3772-4cf9-88a5-3fe126883d15-pvc-667f2e5a-77d5-4b67-bb55-ea3efa6749e1   true         pvcnas                              304Ki         csi-snap-class   snapcontent-49668534-3a05-4218-8e84-94ee96a46482   79s            79s
```

Browsing through the bucket, you will also find the content of the snapshot (the metadata):  
```console
SNAPPATH=$(kubectl get snapshot nasappsnap -n nasapp -o=jsonpath='{.status.appArchivePath}')
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$SNAPPATH --recursive  
```
```console
2025-10-24 14:51:22       1310 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/application.json
2025-10-24 14:51:22          3 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/exec_hooks.json
2025-10-24 14:51:30       2545 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/post_snapshot_execHooksRun.json
2025-10-24 14:51:28       2568 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/pre_snapshot_execHooksRun.json
2025-10-24 14:51:22       2515 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/resource_backup.json
2025-10-24 14:51:26       7127 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/resource_backup.tar.gz
2025-10-24 14:51:26       4122 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/resource_backup_summary.json
2025-10-24 14:51:30       4654 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/snapshot.json
2025-10-24 14:51:30       1074 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/volume_snapshot_classes.json
2025-10-24 14:51:30       1870 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/volume_snapshot_contents.json
2025-10-24 14:51:30       2220 nasapp_1adc96ae-be9f-41fb-9aee-4a50eba2a5ed/snapshots/20251024145122_nasappsnap_32120d0a-3772-4cf9-88a5-3fe126883d15/volume_snapshots.json
```

## C. Backup creation  

Creating an app backup consists in several steps:  
- create an application snapshot if none is specified in the procedure  
- copy the app metadata to the AppVault  
- copy the PVC data to the AppVault
This is also potentially done in conjunction with _hooks_ in order to interact with the app. This part is not covered in this chapter.  
The duration of the backup process takes a bit more time compared to the snapshot, as data is also copied to the bucket.  
```console
tridentctl-protect create backup nasappbkp1 --app nasapp --snapshot nasappsnap --appvault ontap-vault  -n nasapp
tridentctl-protect get backup -n nasapp
```
```console
+------------+--------+----------------+-----------+-------+-------+
|    NAME    |  APP   | RECLAIM POLICY |   STATE   | ERROR |  AGE  |
+------------+--------+----------------+-----------+-------+-------+
| nasappbkp1 | nasapp | Retain         | Completed |       | 2m12s |
+------------+--------+----------------+-----------+-------+-------+
```
If you check the bucket, you will see more subfolders appear:  
```console
APPPATH=$(echo $SNAPPATH | awk -F '/' '{print $1}')
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$APPPATH/
```
```console

                           PRE backups/
                           PRE kopia/
                           PRE snapshots/
```
The *backups* folder contains the app metadata, while the *kopia* one contains the data.  

## D. Scheduling  

Creating a schedule to automatically take snapshots & backups can also be done with the cli.  
Update frequencies can be chosen between _hourly_, _daily_, _weekly_ & _monthly_.  
For this lab, in order to witness scheduled snapshots & backups, it is probably better to move to a faster frequency, done with _custom_ granularity.  
This this example, let's switch to YAML:  
```console
cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: Schedule
metadata:
  name: nasapp-sched
  namespace: nasapp
spec:
  appVaultRef: ontap-vault
  applicationRef: nasapp
  backupRetention: "3"
  dataMover: Kopia
  enabled: true
  granularity: Custom
  recurrenceRule: |-
    DTSTART:20250106T000100Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  snapshotRetention: "3"
EOF
tridentctl-protect get schedule -n nasapp
```
```console
+--------------+--------+--------------------------------+---------+-------+-------+-----+
|     NAME     |  APP   |            SCHEDULE            | ENABLED | STATE | ERROR | AGE |
+--------------+--------+--------------------------------+---------+-------+-------+-----+
| nasapp-sched | nasapp | DTSTART:20250106T000100Z       | true    |       |       | 41s |
|              |        | RRULE:FREQ=MINUTELY;INTERVAL=5 |         |       |       |     |
+--------------+--------+--------------------------------+---------+-------+-------+-----+
```
## :trident: Scenario 07 - Restoring an application

When restoring applications with Trident Protect, you can achieve the following:
- Restore from a snapshot  
-- in-place or to a new namespace  
-- full or partial  
- Restore from a backup
-- in-place or to a new namespace  
-- on the same Kubernetes cluster or a different one  
-- full or partial  

Let's dig into some of those possibilities:  
## A. In-place partial snapshot restore  

Let's first delete the content of one of the volume mounted on the pod (_nas_).  
```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- rm -f /nas/test.txt
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
```
```console
tridentctl-protect create sir nasappsir1 --snapshot nasapp/nasappsnap --resource-filter-include='[{"labelSelectors":["volume=volnas"]}]' -n nasapp
```
The process will take some moment, you can check for the progress with the following commands. You will see that the pvc and the pod will disappear as we are going to restore them. 
```console
tridentctl-protect get sir -n nasapp; kubectl -n nasapp get pod,pvc
```
If everything was successful you should see an output, similar to this:

```console
+------------+-------------+-----------+-------+-------+
|    NAME    |  APPVAULT   |   STATE   | ERROR |  AGE  |
+------------+-------------+-----------+-------+-------+
| nasappsir1 | ontap-vault | Completed |       | 1m31s |
+------------+-------------+-----------+-------+-------+
NAME                          READY   STATUS    RESTARTS   AGE
pod/busybox-6db6b5964-qwhv2   1/1     Running   0          25s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/pvcnas   Bound    pvc-667f2e5a-77d5-4b67-bb55-ea3efa6749e1   1Gi        RWO            sc-nas         <unset>                 28s
```

# check result
```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- ls /nas/
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
```

## B. In-place restore of a backup 

For this test, let's first delete the DEPLOY & the 2 PVC from the namespace:  
```console
kubectl delete -n nasapp deploy busybox
kubectl delete -n nasapp pvc --all
```
=> "Ohlalalalalala, I deleted my whole app! what can I do?!"  

Easy answer, you restore everything from a backup!  

Let's see that in action:  
```console
tridentctl-protect create bir nasappbir -n nasapp --backup nasapp/nasappbkp1
```
```console
tridentctl-protect get bir -n nasapp
```
This again will take some time.
```console
+-----------+-------------+---------+-------+-----+
|   NAME    |  APPVAULT   |  STATE  | ERROR | AGE |
+-----------+-------------+---------+-------+-----+
| nasappbir | ontap-vault | Running |       | 13s |
+-----------+-------------+---------+-------+-----+
```

As soon as the state changes to Completed, you should be able to see the ressources we've delete again

```console
kubectl -n nasapp get po,pvc
```
```console
NAME                          READY   STATUS    RESTARTS   AGE
pod/busybox-6db6b5964-dtd79   1/1     Running   0          87s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/pvcnas   Bound    pvc-b0d2d2b0-ba94-4016-88fb-e482818d6697   1Gi        RWO            sc-nas         <unset>                 88s
```
Our app is back, but what about the data:  
```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
```
```console
Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!
```
:trident::trident::trident:  
Success! Congratulations to you, if you read this lines you are at the end of this small lab. If you went through all the tasks, you were able to install and configure Trident and Trident protect, run your first app, protect, destroy and recreate it.  
:trident::trident::trident:


