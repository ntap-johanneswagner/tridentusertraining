## :trident: Prelude

First a big thank you to [Yves Weisser](github.com/yvosonthehub) as his LabNetApp repository is the foundation of this training material. I highly recommend to have look at his work and redo this from time to time as he is doing a tremendous job, explaining all the Trident functionalities with real good examples. 

**The Lab guide is only needed for getting the usernames and passwords. Please ignore the tasks in the lab guide, everything you need is in this github repository.**

Access the host *rhel3* via putty to perform all of the tasks.

## :trident: Scenario 01 - Configure Trident
**Remember: All required files are in the folder */root/tridentusertraining/scenario01* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridentusertraining/scenario01
```
Installation is quiet easy and straight forward and already done, the fun begins with the configuration. Trident was installed in the Namespace trident, you can quickly have a look at the pods:

```console
kubectl get pods -n trident
```

If everything is successfull you should see one controller pod and one node pod per kubernetes node.

As our cluster has 3 linux and 2 windows nodes, the output should look like this:
```console
k get pods -n trident

NAME                                 READY   STATUS    RESTARTS   AGE
trident-controller-5c6c9856d-jd8qc   6/6     Running   0          3m25s
trident-node-linux-6r5h8             2/2     Running   0          3m24s
trident-node-linux-cjkqq             2/2     Running   0          3m24s
trident-node-linux-th7mx             2/2     Running   0          3m24s
trident-node-windows-8cfzg           3/3     Running   0          3m23s
trident-node-windows-nlfqs           3/3     Running   0          3m23s
trident-operator-77f4f5f7f5-4wfb6    1/1     Running   0          4m14s
```


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
```
```console
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
```
```console
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
```
```console
volumesnapshotclasses.snapshot.storage.k8s.io         2024-04-27T21:06:08Z
volumesnapshotcontents.snapshot.storage.k8s.io        2024-04-27T21:06:08Z
volumesnapshots.snapshot.storage.k8s.io               2024-04-27T21:06:08Z
```
```console
kubectl get all -n kube-system -l app=snapshot-controller
```
```console
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
```
```console
kubectl get pods,pvc -n nasapp
```
```console
kubectl get pods,pvc -n nasecoapp
```
```console
kubectl get pods,pvc -n sanapp
```
```console
kubectl get pods,pvc -n sanecoapp
```

If there are errors or things stuck in pending, the first you should do is to have a look by using kubectl describe. Possible objects to start: Pod, PVC, trident controller.

Also let's try out whether we really can write data and read it again:

```console
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!" > /nas/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas-economy driver!" > /naseco/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san driver!" > /san/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san-economy driver!" > /saneco/test.txt'
```
```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!" > /nas/test.txt'
```
```console
kubectl exec -n nasecoapp $(kubectl get pod -n nasecoapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas-economy driver!" > /naseco/test.txt'
```
```console
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san driver!" > /san/test.txt'
```
```console
kubectl exec -n sanecoapp $(kubectl get pod -n sanecoapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san-economy driver!" > /saneco/test.txt'
```


```console
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /nas/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /naseco/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /san/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /saneco/test.txt
```
```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
```
```console
kubectl exec -n nasecoapp $(kubectl get pod -n nasecoapp -o name) -- more /naseco/test.txt
```
```console
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- more /san/test.txt
```
```console
kubectl exec -n sanecoapp $(kubectl get pod -n sanecoapp -o name) -- more /saneco/test.txt
```

## :trident: Scenario 03 - running out of space? Let's expand the volume
**Remember: All required files are in the folder */root/tridentusertraining/scenario03* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridentusertraining/scenario03
```

Sometimes you need more space than you thought before. For sure you could create a new volume, copy the data and work with the new bigger PVC but it is way easier to just expand the existing.

First let's check the StorageClasses

```console
kubectl get sc 
```

Look at the column *ALLOWVOLUMEEXPANSION*. As we specified earlier, both StorageClasses are set to *true*, which means PVCs that are created with this StorageClass can be expanded.  
NFS Resizing was introduced in K8S 1.11, while iSCSI resizing was introduced in K8S 1.16 (CSI)

Now let's create two PVCs and a busybox container using these PVCs, in their own namespace called *resize".

```console
kubectl apply -f resizeapp.yaml
```

Wait until the pod is in running state - you can check this with the command

```console
kubectl get pod -n resize
```

Finaly you should be able to see that the 5G volume is indeed mounted into the POD

```console
kubectl exec -n resize $(kubectl get pod -n resize -o name) -- df -h /nfsstorage
kubectl exec -n resize $(kubectl get pod -n resize -o name) -- df -h /iscsistorage
```

Resizing a PVC can be done in different ways. We will edit the definition of the nfsstorage PVC & manually modify it.  
Look for the *storage* parameter in the spec part of the definition & change the value (in this example, we will use 15GB)
The provided command will open the pvc definition.

```console
kubectl -n resize edit pvc nfsstorage
```

change the size to 15Gi like in this example:

```yaml
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 15Gi
  storageClassName: sc-nas
  volumeMode: Filesystem
```

you can insert something by pressing "i", exit the editor by pressing "ESC", type in :wq! to save&exit. 

Everything happens dynamically without any interruption. The results can be observed with the following commands:

```console
kubectl -n resize get pvc
kubectl exec -n resize $(kubectl get pod -n resize -o name) -- df -h /nfsstorage
```

This could also have been achieved by using the *kubectl patch* command. Try the following, this time for the blockstorage:

```console
kubectl patch -n resize pvc iscsistorage -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

So increasing is easy, what about decreasing? Try to set your volume to a lower space, use the edit or the patch mechanism from above.
___

<details><summary>Click for the solution</summary>

```console
kubectl patch -n resize pvc nfsstorage -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
```
</details>

___

Even if it would be technically possible to decrease the size of a NFS volume, K8s just doesn't allow it. So keep in mind: Bigger ever, smaller never. 

:trident::trident::trident:  
Congratulations - You configured Trident and created your first applications that leveraged persistent storage. In addition, you also saw some of the typical errors and solved them. This marks the end of the first hands on part of this training.  
:trident::trident::trident:

## :trident: Scenario 04 - Snapshots here and there...
**Remember: All required files are in the folder */root/tridentusertraining/scenario03* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridentusertraining/scenario04
```

The following will walk you through the management of snapshots with a simple lightweight BusyBox container.

You are going to work with the nasapp you created in Scenario02, Data has already been written there.

Creating a snapshot of this volume is very simple. The necessary file is already prepared and in the scenario folder. Have a look at it and apply it afterwards.  

```console
kubectl apply -f pvc-snapshot.yaml
```

After it is created you can observe its details:
```console
kubectl get volumesnapshot -n nasapp
```
Your snapshot has been created !  

To experiment with the snapshot, let's delete our test file...
```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- rm -f /nas/test.txt
```

If you want to verify that the data is really gone, feel free to try out the command from above that has shown you the contents of the file:

```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
```

One of the useful things K8s provides for snapshots is the ability to create a clone from it. 
If you take a look a the PVC manifest (_pvc_from_snap.yaml_), you can notice the reference to the snapshot:

```yaml
dataSource:
  name: pvcnas-snapshot
  kind: VolumeSnapshot
  apiGroup: snapshot.storage.k8s.io
```

Let's see how that turns out:

```console
kubectl apply -f pvc_from_snap.yaml
```

This will create a new pvc which could be used instantly in an application. You can see it if you take a look at the pvcs in your namespace:

```console
kubectl get pvc -n nasapp
```

Recover the data of your application

When it comes to data recovery, there are many ways to do so. If you want to recover only a single file, you can temporarily attach a PVC clone based on the snapshot to your pod and copy individual files back. Some storage systems also provide a convenient access to snapshots by presenting them as part of the filesystem (feel free to exec into the pod and look for the .snapshot folders on your PVC). However, if you want to recover everything, you can just update your application manifest to point to the clone, which is what we are going to try now:

```console
kubectl patch -n nasapp deploy nasapp -p '{"spec":{"template":{"spec":{"volumes":[{"name":"volume","persistentVolumeClaim":{"claimName":"pvcnas-from-snap"}}]}}}}'
```

That will trigger a new POD creation with the updated configuration

Now, if you look at the files this POD has access to (the PVC), you will see that the *lost data* (file: test.txt) is back!

```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- ls -l /nas/
```
or even better, lets have a look at the contents:

```console
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
```

Tadaaa, you have restored your data!  
Keep in mind that some applications may need some extra care once the data is restored (databases for instance). In a production setup you'll likely need a more full-blown backup/restore solution.  

Another Option is to use the in-place restore functionality of Trident.
In-place restore will benefit from the ONTAP Snapshot Restore feature, which takes only a couple of seconds whatever size the volume is!  

This time we will use the sanapp.

Let's create the snapshot first again:

```console
kubectl apply -f pvc-snapshot-san.yaml
```

To experiment with the snapshot, let's delete our test file...
```console
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- rm -f /san/test.txt
```

If you want to verify that the data is really gone, feel free to try out the command from above that has shown you the contents of the file:

```console
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- more /san/test.txt
```

In order to use this feature, the volume needs to be detached from its pods.  
Since we are using a deployment object, we can just scale it down to 0:  
```console
kubectl scale deploy busybox --replicas=0 -n sanapp
```
Verify that no pods are running anymore:
```console
kubectl get pod -n sanapp
```

In-place restore will be performed by created a TASR objet ("TridentActionSnapshotRestore"). The file is provided in the folder:
```console
kubectl apply -f snapshot-restore.yaml
```
```console
To verify the status
kubectl get -n sanapp tasr -o=jsonpath='{.items[0].status.state}'; echo
```
We can now restart the pod, and browse through the PVC content.  
If you look at the files this POD has access to (the PVC), you will see that the *lost data* (file: test.txt) is back!
```console
kubectl scale -n sanapp deploy busybox --replicas=1
```
```console
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- ls -l /san/
```
```console
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- more /san/test.txt
```
Tadaaa, you have restored the whole snapshot in one shot!  

# :trident: Scenario 05 - Consumption control 
___
**Remember: All required files are in the folder */root/tridentusertraining/scenario05*. Please ensure that you are in this folder. You can do this with the command**
```console
cd /root/tridentusertraining/scenario05
```
___
There are many different ways to control the storage consumption. We will focus on the possibilities of K8s itself. However please remember: Sometimes the same thing can also be achieved at storage or csi driver level and it might be preferred to do it there.

You can create different objects to control the storage consumption directly in Kubernetes:

- LimitRange: controls the maximum (& minimum) size for each claim in a namespace
- ResourceQuotas: limits the number of PVC or the amount of cumulative storage in a namespace

For this scenario we will create and work in the namespace *control*.

You will create two types of quotas:

1. Limit the number of PVC a user can create
2. Limit the total capacity a user can consume

Take a look at _rq-pvc-count-limit.yaml_ and _rq-sc-resource-limit.yaml_ and then apply them:

```console
kubectl create namespace control
kubectl apply -n control -f rq-pvc-count-limit.yaml
kubectl apply -n control -f rq-sc-resource-limit.yaml
```

You can see the specified ressource quotas with the following command:

```console
kubectl get resourcequota -n control
```

Nice, they are there - but what do they do? Let's take a closer look:

```console
kubectl describe quota pvc-count-limit -n control
```

Ok we see some limitations... but how do they work? Let's create some PVCs to find out

```console
kubectl apply -n control -f pvc-quotasc-1.yaml
kubectl apply -n control -f pvc-quotasc-2.yaml
```

Again, have a look at the ressource limits:

```console
kubectl describe quota pvc-count-limit -n control
```

Two in use, great, let's add a third one

```console
kubectl apply -n control -f pvc-quotasc-3.yaml
```

So far so good, all created, a look at our limits tells you that you got the maximum number of PVC allowed for this storage class. Let's see what happens next...

```console
kubectl apply -n control -f pvc-quotasc-4.yaml
```

Oh! An Error... well that's what we expected as we want to limit the creation, right?
Before we continue, let's clean up a little bit:

```console
kubectl delete pvc -n control --all
```

Time to look at the capacity quotas...

```console
kubectl describe quota sc-resource-limit -n control
```

Each PVC you are going to use is 5GB.

```console
kubectl apply -n control -f pvc-5Gi-1.yaml
```

A quick check:

```console
kubectl describe quota sc-resource-limit -n control
```

Given the size of the second PVC file, the creation should fail in this namespace

```console
kubectl apply -n control -f pvc-5Gi-2.yaml
```

And as expected, our limits are working. 

Before starting the second part of this scenario, let's clean up

```console
kubectl delete pvc -n control 5gb-1
kubectl delete resourcequota -n control --all
```

We will use the LimitRange object type to control the maximum size of the volumes a user can create in this namespace. 

```console
kubectl apply -n control -f lr-pvc.yaml
```

Let's verify:

```console
kubectl describe -n control limitrange storagelimits
```

Now that we have create a 2Gi limit, let's try to create a 5Gi volume...

```console
kubectl apply -n control -f pvc-5Gi-1.yaml
```

Magical, right? By the way, the NetApp Trident CSI driver from this lab has a similar parameter called _limitVolumeSize_ that controls the maximum capacity of a PVC per Trident Backend.  

If you want to try that out, simply add the limitVolumeSize parameter to one of the tbcs. If you use a value of 2gb, you should be able to create the 1gb pvcs we used in the scenario right now, but none of the 5gb pvcs. However, the failure behavior is a little bit different as PVCs will be created but stuck in pending state. 

:trident::trident::trident:  
Success! Congratulations to you, if you read this lines you are at the end of this small lab.
:trident::trident::trident:


