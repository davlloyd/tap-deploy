

# Create configuration files for TAP Packages
# - app-accelerator-values.yaml
# - app-live-view-values.yaml
# - cnr-values.yaml
# - default-supply-chain-values.yaml
# - tbs-values.yaml

function validatePasswords(){
    if [[ -f "$REGISTRY_PASSWORD_FILE" ]]; then
        log "Reading registry password file $REGISTRY_PASSWORD_FILE"
        REGISTRY_PASSWORD=$(cat $REGISTRY_PASSWORD_FILE)
    else
      log "No Registry password file set so using REGISTRY_PASSWORD variable value"
    fi

    if [[ -f "$PIVNET_PASSWORD_FILE" ]]; then
        log "Reading pivotal network password file $PIVNET_PASSWORD_FILE"
        PIVNET_PASSWORD=$(cat $PIVNET_PASSWORD_FILE)
    else
      log "No pivotal network password file set so using PIVNET_PASSWORD variable value"
    fi

}

log "Reading password information"
validatePasswords

shopt -s nocasematch
if [ "$DEPLOYMENT_MODEL" == "cluster" ]; then
    SERVICE_TYPE="LoadBalancer"
    CNR_PROVIDER=""
else
    SERVICE_TYPE="NodePort"
    CNR_PROVIDER="provider: local"
fi
shopt -u nocasematch

cat > "app-accelerator-values.yaml" <<EOF
server:
  service_type: "$SERVICE_TYPE"
  watched_namespace: "$DEV_NAMESPACE"
EOF

cat > "app-live-view-values.yaml" <<EOF
---
connector_namespaces: [$DEV_NAMESPACE]
server_namespace: app-live-view
EOF

cat > "cnr-values.yaml" <<EOF
---
$CNR_PROVIDER
EOF

cat > "default-supply-chain-values.yaml" <<EOF
---
registry:
  server: $REGISTRY_HOST
  repository: $REGISTRY_PROJECT
service_account: service-account
EOF


cat > "tbs-values.yaml" <<EOF
---
kp_default_repository: $REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_TBS
kp_default_repository_username: $REGISTRY_ACCOUNT
kp_default_repository_password: '$REGISTRY_PASSWORD'
tanzunet_username: $PIVNET_ACCOUNT
tanzunet_password: $PIVNET_PASSWORD
EOF

cat > "cnr-custom-domain.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-domain
  namespace: knative-serving
data:
  $CUSTOM_DOMAIN: ""
EOF
