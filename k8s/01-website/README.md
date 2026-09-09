# Website stack (static + API + MariaDB)

Canonical manifests for CI live in the **surfhouse** repo (`surfhouse/k8s/`).
Copies here keep the homelab tree complete for manual `kubectl apply`.

```bash
# one-time secret (or let GitLab deploy job create it from DB_PASSWORD)
kubectl -n website create secret generic surfhouse-db \
  --from-literal=password='CHANGE_ME' \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f mariadb.yml -f api.yml -f ingress.yml
kubectl apply -f deployment.yml -f service.yml
```
