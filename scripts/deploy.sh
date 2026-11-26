#!/usr/bin/env bash
# Installs everything inside the cluster: Envoy Gateway, cert-manager, secrets, the textlib chart, the
# editor user. Safe to run again (helm upgrade --install, secrets are kept).
# Usage: scripts/deploy.sh <provider>
source "$(dirname "$0")/lib.sh"
load_config

log "Cluster credentials ($PROVIDER)"
get_kube_credentials

log "Envoy Gateway $ENVOY_GATEWAY_VERSION (also installs the Gateway API CRDs)"
helm upgrade --install "${HELM_ARGS[@]}" eg "$ENVOY_GATEWAY_CHART" --version "$ENVOY_GATEWAY_VERSION" \
  --namespace envoy-gateway-system --create-namespace --wait --timeout 10m

log "cert-manager $CERT_MANAGER_VERSION (with Gateway API support)"
helm upgrade --install "${HELM_ARGS[@]}" cert-manager "$CERT_MANAGER_CHART" --version "$CERT_MANAGER_VERSION" \
  --namespace cert-manager --create-namespace --wait --timeout 10m \
  --set crds.enabled=true \
  --set config.apiVersion=controller.config.cert-manager.io/v1alpha1 \
  --set config.kind=ControllerConfiguration \
  --set config.enableGatewayAPI=true

log "Secrets"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
existing() { kubectl -n "$NAMESPACE" get secret textlib-secrets -o "jsonpath={.data.$1}" 2>/dev/null | base64 -d || true; }
random() { openssl rand -hex 32; }
CLIENT_SECRET=$(existing client-secret); CLIENT_SECRET=${CLIENT_SECRET:-$(random)}
AUTH_SECRET=$(existing auth-secret); AUTH_SECRET=${AUTH_SECRET:-$(random)}
KC_ADMIN_PASSWORD=$(existing kc-admin-password); KC_ADMIN_PASSWORD=${KC_ADMIN_PASSWORD:-$(random)}
DB_PASSWORD=$(get_secret db-password)
kubectl -n "$NAMESPACE" create secret generic textlib-secrets \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=client-secret="$CLIENT_SECRET" \
  --from-literal=auth-secret="$AUTH_SECRET" \
  --from-literal=kc-admin-password="$KC_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "textlib-secrets ok (values not printed)"

log "textlib chart (image tag $IMAGE_TAG)"
helm upgrade --install "${HELM_ARGS[@]}" textlib "$ROOT/platform/charts/textlib" --namespace "$NAMESPACE" \
  -f "$ROOT/platform/values/$PROVIDER.yaml" \
  --set-string domain="$DOMAIN" \
  --set-string appName="$APP_NAME" \
  --set-string realm="$REALM_NAME" \
  --set-string clientId="$CLIENT_ID" \
  --set-string tls.issuer="$TLS_ISSUER" \
  --set-string tls.acmeEmail="${ACME_EMAIL:-}" \
  --set-string images.registry="$(tf_output registry_login_server)" \
  --set-string images.tag="$IMAGE_TAG" \
  --set-string images.keycloak="$KEYCLOAK_IMAGE" \
  --set-string db.host="$(tf_output db_host)" \
  --set-string db.user="$(tf_output db_user)" \
  --wait --timeout 15m

log "Editor user"
kc() { kubectl -n "$NAMESPACE" exec deploy/keycloak -- /opt/keycloak/bin/kcadm.sh "$@"; }
kc config credentials --server http://localhost:8080 --realm master \
  --user admin --password "$KC_ADMIN_PASSWORD" >/dev/null
kc create users -r "$REALM_NAME" -s username="$EDITOR_USERNAME" -s enabled=true \
  -s email="$EDITOR_USERNAME@example.com" -s emailVerified=true \
  -s firstName="$EDITOR_USERNAME" -s lastName="User" >/dev/null 2>&1 || echo "user exists"
kc set-password -r "$REALM_NAME" --username "$EDITOR_USERNAME" --new-password "$EDITOR_PASSWORD"
kc add-roles -r "$REALM_NAME" --uusername "$EDITOR_USERNAME" --rolename editor

log "Load balancer address"
IP=""
for _ in $(seq 1 30); do
  IP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-name=textlib \
    -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [[ -n "$IP" ]] && break
  sleep 10
done
cat <<EOF

Set these DNS A records at your registrar (if not done yet):
  $DOMAIN        A  ${IP:-<pending – rerun later>}
  auth.$DOMAIN   A  ${IP:-<pending>}

Then check the certificates:  kubectl -n $NAMESPACE get certificate
App:      https://$DOMAIN
Keycloak: https://auth.$DOMAIN
EOF
