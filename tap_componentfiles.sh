
# *********** Create Component configuration files ***************

log "Creating configuration file: app-accelerator-values.yaml"

cat > "app-accelerator-values.yaml" <<EOF
server:
  service_type: "$SERVICE_TYPE"
  watched_namespace: "$DEV_NAMESPACE"
samples:
  include: true
EOF


log "Creating configuration file: app-live-view-values.yaml"

cat > "app-live-view-values.yaml" <<EOF
---
connector_namespaces: [$DEV_NAMESPACE]
server_namespace: app-live-view
EOF

####
log "Creating configuration file: ootb-supply-chain-values.yaml"

cat > "ootb-supply-chain-values.yaml" <<EOF
---
registry:
  server: $REGISTRY_HOST
  repository: $REGISTRY_PROJECT
service_account: service-account
EOF

####
log "Creating configuration file: tbs-values.yaml"

cat > "tbs-values.yaml" <<EOF
---
kp_default_repository: $REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_TBS
kp_default_repository_username: $REGISTRY_ACCOUNT
kp_default_repository_password: '$REGISTRY_PASSWORD'
tanzunet_username: $PIVNET_ACCOUNT
tanzunet_password: $PIVNET_PASSWORD
EOF

####
log "Creating configuration file: cnr-custom-domain.yaml"

cat > "cnr-custom-domain.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-domain
  namespace: knative-serving
data:
  $CUSTOM_DOMAIN: ""
EOF

####
log "Creating configuration file: scst-store-values.yaml"

cat > "scst-store-values.yaml" <<EOF
db_password: "PASSWORD-0123"
app_service_type: "$SERVICE_TYPE"
EOF

####
log "Creating configuration file: scst-sign-values.yaml"

cat > "scst-sign-values.yaml" <<EOF
---
warn_on_unmatched: true
EOF

####
log "Creating configuration file: scst-scan-controller-values.yaml"

cat > "scst-scan-controller-values.yaml" <<EOF
api_host: "localhost"
api_port: 9443
app_service_type: "LoadBalancer"
auth_proxy_host: "0.0.0.0"
auth_proxy_port: 8443
db_host: "metadata-store-db"
db_name: "metadata-store"
db_password: "password"
db_port: "5432"
db_sslmode: "verify-full"
db_user: "metadata-store-user"
storageClassName: "manual"
use_cert_manager: "true"
EOF

