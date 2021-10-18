# DevOps Engineer Assignment

## Requirements
- We want to deploy a highly-available Elasticsearch (ES) cluster.
- It should be done using Docker and Kubernetes.
- The cluster should be on multiple hosts/worker nodes, rather than just multiple pods/containers.
- The Elasticsearch roles assigned to the each cluster instance should be the same
- Can be deployed on cloud cluster or local machine


## Introduction
In order to create a HA ElasticSearch cluster in Kubernets, ElasticSearch is going to be installed using ElasticSearch cloud on Kubernetes (ECK)
nodes will have the same 3 roles(master,data,ingest) and will be deployed across kubernetes nodes.
The storage is going to be dynamically created through storageclass and backed up in the AWS s3 Bucket cloud via ElasticSearch snapshot plugins.

## High availability (HA) ElasticSearch cluster

### Installation
The preferred way to install Elastic search is through ElasticSearch cloud on Kubernetes (ECK) because simplifies setup, upgrades, snapshots, scaling, high availability and security.
ECK works in every flavor of Kubernetes from cloud to on-premise clusters.

### Pod Distribution
In order to achieve high availability the ElasticSearch cluster should have nodes deployed in multiple Kubernetes nodes/hosts,
because if one node or multiple nodes fail the ElasticSearch cluster can keep working.
To do so, the cluster yaml definition implements podAntiAffinity with preferredDuringSchedulingIgnoredDuringExecution in order
to indicate to the scheduler to prefer run pods in nodes that do not have a pod related to an "ElasticSearch" node.

The ElasticSearch documentation indicates use nodeAffinity to allow pods to be schedule accross multiple node/hosts, but this approach,
requires to be tied to a set of specific cloud provider node labels, the podAntiAffinity achieve the same results without being tied to any cloud provider.

The amount of ElasticSearch nodes is managed via Helm values(3 as default), each node has been configured to have the three same roles(master, data, ingest)

### Storage
Configurations, data and indexes are stored in volumes, so if the volume goes down , the entire ElasticSearch cluster is going to fail.
In order to achieve HA a more resilient storage solution that the default volatile pod storage is needed. Thankfully in Kubernetes 
there are multiple native ways to connect to HA storage, from the popular mayor clouds (azure, GCP, Amazon), specific services such as StorageOS
to on-premise solutions.

The selected approach to provision the storage is through persistant volume claims(PVC), this PVCs refers to a storageclass in order to dynamically provisioning the storage (volumes) from outside the kubernetes cluster.
In the installation you can switch between AWS cloud storage to NFS storage, just changing a parameter. Because the storage is created dynamically by kubernetes cluster, change between AWS storage to NFS will be transparent at the moment of the installation.

This enables you to use resilient storage in the cloud or on-premise environemts without effort.


## Backups
There are multiple native plugins to take incremental snapshots of the ElasticSearch cluster(ECK) data, 
these snapshots should be stored outside the cluster, because if the kubernetes cluster fails, ElasticSearch can be recovered in other Kubernetes cluster.
Its also recomended take snapshots of the storage that contains the ECK snapshots in order to have specific restore points.

The selected approach to manage the backups is via AWS snapshot plugin, because the cloud brings a lot of capabilities such as soft delte, data snapshots, access from any place in the world, high throughput. All these with minimal effort.

There are multiple ECK cluster plugins to take the snapshots, this is good because we can switch from cloud provider without rebuild the entire backup solution.
Following other available plugins:
- repository-s3 for S3 repository support
- repository-hdfs for HDFS repository support in Hadoop environments
- repository-azure for Azure storage repositories
- repository-gcs for Google Cloud Storage repositories

## Deployment

The selected approach is, use a custom helm chart in order to deploy all the resources related to the elasticsearch at once. Also enable us to to perform upgrades or rollbacks to the cluster definitions.

There are 3 main components to be deployed/Configurated:
- ECK
- ElasticSearch cluster
- Backups

### Prerequisites
Following the prerequisites:
- Verify Kubectl is already installed and accessible in your terminal.
- Verify Helm 3 is already installed and accessible in your terminal.
- Clone git repository.
- Open the console and change the current directory to the repository directory.
- Verify you are able to comunicate with your kubernetes cluster via kubectl.
- NFS with a path exposed with property "no_root_squash" ready to be used (if you choose this storage rather than cloud storage, on-premise envs).

### Install ECK 1.8.0
run the followig commands

```sh
kubectl create -f https://download.elastic.co/downloads/eck/1.8.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/1.8.0/operator.yaml
```

## Install NFS provisioner
If you choose NFS as storage for your cluster run the following commands

```sh
# Add repo
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
# Install Chart
helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server={server name or IP} \
    --set nfs.path={path}
```

### Deploy ElasticSearch cluster
The cluster deployment yaml files along with the other kubernetes objects and configurations
are being deployed via a custom Helm chart, this chart is located in the "eschart" folder.

To verify the objects you are going to install run the following script

```sh
##Show yamls
helm template --debug elasticha ./eschart \
--set s3.keyid="{aws s3 key id in base64}" --set s3.secretkey="{aws s3 secret key in base64}" \
--set storageToUse.nfs=true

## if you are running the ES cluster in the cloud you might use aws storage
#--set storageToUse.aws=true

## Change amount of ES nodes
#--set replicaCount={number of nodes}

```

To install the objects in kubernets run the following command

```sh
##Install ElasticSearch Cluser
helm upgrade --install --debug elasticha ./eschart \
--set keyid.keyid="{aws s3 key id in base64}" --set keyid.secretkey="{aws s3 secret key in base64}" \
--set storageToUse.nfs=true

## if you are running the ES cluster in the cloud you might use aws storage
#--set storageToUse.aws=true

## Change amount of ES nodes
#--set replicaCount={number of nodes}

```

To show the helm chart values run the following command.

```hs
helm show values ./eschart
```

### Configure backups
Run the following script located in backups folder

```sh
config-backup.sh "{bucket name}" "{region}" "{basepath}"
```
this send a request to the aws plugin installed in the ElasticSearch nodes to start sending the snapshots to the desired AWS S3 bucket.

### Take Snapshot
Run the following script located in backups folder
```sh
take-snapshot.sh "{snapshot name}"
```
This takes a snapshot and show you the status

## Operations

### Metrics to look
From the infraestructure perspective there are 3 principal metrics to take a look
- Storage space: The volume claims are static so if the storage become full you need create another one and restore snapshots if needed.
- Memory: ElasticSearch is a very intensive memory application so you need to be aware of the available momory in the kubernetes cluster
- CPU: ElasticSearch is a high consumption CPU app so you need to be aweare of the CPU consumpion in order to not starve cluster apps.


### Update/RollBack
You are able to modify the ElasticSearch cluster specifications and the operator is going to be in charge of apply those changes to the cluster.
Since the ElasticSearch cluster is being install via a custom helm chart you can update and rollback version easly, as a normal helm chart.

You just need to be aware that the volume claims cannot be downsized.

### Mantainance Tasks
- Manage snapshots(create, delete)
- Create node according to the desired tiers
- Upgrade ECK version
- Redimention storage
- Manage cluster size