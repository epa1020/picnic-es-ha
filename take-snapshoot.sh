snapshotname=$1

podname=$(kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=ha' --output=jsonpath={.items[0]..metadata.name})
PASSWORD=$(kubectl get secret ha-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode)

kubectl exec "$podname" -- curl -u "elastic:$PASSWORD" \
-k --request PUT "https://localhost:9200/_snapshot/mybackup/$snapshotname"

kubectl exec "$podname" -- curl -u "elastic:$PASSWORD" \
-k --request GET "https://localhost:9200/_snapshot/mybackup/$snapshotname"