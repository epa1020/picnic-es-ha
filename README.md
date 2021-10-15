# DevOps Engineer Assignment

## Requirements
- We want to deploy a highly-available Elasticsearch (ES) cluster.
- It should be done using Docker and Kubernetes.
- The cluster should be on multiple hosts/worker nodes, rather than just multiple pods/containers.
- The Elasticsearch roles assigned to the each cluster instance should be the same
- Can be deployed on cloud cluster or local machine


## Introduction
In order to create a HA ElasticSearch cluster in Kubernets, ElasticSearch is going to be installed using ElasticSearch cloud on Kubernetes (ECK),
nodes will have the same 3 roles(master,data,ingest) and will be deployed accross kubernetes nodes.
The storage is going to be dinamically created through storageclass and backed up in the azure cloud via ElasticSearch snapshot plugins.

## High availability (HA) ElasticSearch cluster

### Installation
The prefer way to install Elastic search is through ElasticSearch cloud on Kubernetes (ECK) because simplifies setup, upgrades, snapshots, scaling, high availability, security.
ECK works in every flavor of Kubernetes from cloud to on-premise clusters.

### Pod Distribution
In order to achive high availability the ElasticSearch cluster should have nodes deployed in multiple Kubernetes nodes/hosts,
because if one node or multiple nodes fail the ElasticSearch cluster can keep working.
To do so, the cluster yaml definition implements podAntiAffinity with preferredDuringSchedulingIgnoredDuringExecution in order
to indicate to the scheduler to prefer run pods in nodes that do not have a pod related to an "ElasticSearch" node.

The ElasticSearch documentation indicates use nodeAffinity to allow pods to be schedule accross multiple node/hosts, but this approach,
requires to be tied to a set of specific cloud provider node labels, the podAntiAffinity achive the same results without being tied to any cloud provider.

### Storage
Configurations, data and indexes are stored in volumes, so if the volume goes down , the entire ElasticSearch cluster is going to fail.
In order to achive HA a more resiliant storage solution that the default volatile pod storage is needed. Thanksfully in Kubernetes 
there are multiple native ways to connect to HA storage, from the popular mayor clouds (azure, GCP, Amazon), specifc services such as StorageOS
to on-premise solutions.

The selected approach to provision the storage is through persistant volume claims(PVC), this PVCs refers to a storageclass in order to dynamically
provisioning the storage (volumes) from outside the kuberntes cluster.
This storageclass can be easly replaced in the HELM chart values (see deploy section) depending if the cluster is going to run in azure, GCP, Amazon or locally

## Backups
In order to backup the data of the ElasticSearch cluster(ECK) there are multiple native plugins to take incremental snapshots, 
this snapshots are stored outside the cluster, so if the kubernetes cluster fails ElasticSearch can be recovered in other Kubernetes cluster.
If needed take snapshot of the storage that contains the ECK snapshot in order to have specific restore points.

The selected approach to manage the backups is via azure snapshot plugin, but the ECK clustor is not going to be tied to an specific cloud provider,
following other available plugins easy to use:
- repository-s3 for S3 repository support
- repository-hdfs for HDFS repository support in Hadoop environments
- repository-azure for Azure storage repositories
- repository-gcs for Google Cloud Storage repositories

Azure was selected regarding its features, soft delete, automatic backups, security, pricing.

## Deployment
There are 3 main components to be deployed/Configurated:
- Install ECK
- Deploy ElasticSearch cluster
- Configure backups

### Prerequisites
Following the prerequisites:
- Verify Kubectl is already installed and accessible in your terminal.
- Verify Helm 3 is already installed and accessible in your terminal.
- Clone git repository.
- Open the console and change the current directory to the repository directory.
- Verify you are able to comunicate with your kubernetes cluster via kubectl.

### Install ECK 1.8.0
run the followig scripts

```sh
kubectl create -f https://download.elastic.co/downloads/eck/1.8.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/1.8.0/operator.yaml
```

## Install NFS provisioner (just for on-premise envs)

```sh
helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server={server name or IP} \
    --set nfs.path={path}
```

### Deploy ElasticSearch cluster
The cluster deployment yaml files along with the other kubernetes objects and configurations
are being deployed via a custom Helm chart.

To verify the objects you are going to install run the following script

```sh
helm template --debug elasticha ./eschart \
--set storageAcc.accKey="{azure account key}" --set storageAcc.accName="{azure account name}"
```

To install the objects in kubernets run the following command

```sh
helm upgrade --install --debug elasticha ./eschart --set storageAcc.accKey="{azure account key}" --set storageAcc.accName="{azure account name}"

## to install using on-premise NFS storage
## pass a different volume claim as helm value
## Example:
## [
##   {
##     "metadata": {
##       "name": "elasticsearch-data"
##     },
##     "spec": {
##       "accessModes": [
##         "ReadWriteOnce"
##       ],
##       "resources": {
##         "requests": {
##           "storage": "10Gi"
##         }
##       },
##       "storageClassName": "nfs-client"
##     }
##   }
## ]
```

To show the helm chart values run the following command, 

```hs
helm show values ./eschart
```


### Configure backups
Run the foollowing script located in backups folder

```sh
config-backup.sh "{azure blob container}" "{storage account}" "{storage account key}"
```
this send a request to the azure plugin installed in the ElasticSearch nodes to start sending the snapshots to the azure storage account to the desire container(bucket)
