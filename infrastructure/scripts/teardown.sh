#!/usr/bin/env bash
# Removes everything deploy.sh installed, in reverse order, and waits until the cloud load balancer
# is released – otherwise "terraform destroy" can hang on the network resources.
# Usage: infrastructure/scripts/teardown.sh <provider>
source "$(dirname "$0")/lib.sh"

log "Cluster credentials ($PROVIDER)"
get_kube_credentials

log "Uninstall textlib, cert-manager, Envoy Gateway"
helm uninstall textlib --namespace "$NAMESPACE" --wait --ignore-not-found
helm uninstall cert-manager --namespace cert-manager --wait --ignore-not-found
helm uninstall eg --namespace envoy-gateway-system --wait --ignore-not-found

log "Wait until no LoadBalancer service is left"
for _ in $(seq 1 30); do
  n=$(kubectl get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' | grep -c . || true)
  [[ "$n" == "0" ]] && break
  echo "  $n LoadBalancer service(s) left, waiting …"
  sleep 10
done

kubectl delete namespace "$NAMESPACE" cert-manager envoy-gateway-system --ignore-not-found --wait=true
echo
echo "Cluster is empty. Next: terraform -chdir=infrastructure/terraform destroy"
