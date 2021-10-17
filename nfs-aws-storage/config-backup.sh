podname=$(kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=ha' --output=jsonpath={.items[0]..metadata.name})
PASSWORD=$(kubectl get secret ha-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode)

kubectl exec "$podname" -- curl -u "elastic:$PASSWORD" \
 -k --request PUT "https://localhost:9200/_snapshot/mybackup" \
 -H 'Content-Type: application/json' -d'
{
"type": "s3",
  "settings": {
    "bucket": "picnicsebucket",
    "region": "us-east-2",
    "base_path": "backups"
  }
}
'


kubectl exec "$podname" -- curl -u "elastic:$PASSWORD" \
-k --request PUT "https://localhost:9200/_snapshot/mybackup/snapshot_1"

kubectl exec "$podname" -- curl -u "elastic:$PASSWORD" \
-k --request GET "https://localhost:9200/_snapshot/mybackup/snapshot_1"

