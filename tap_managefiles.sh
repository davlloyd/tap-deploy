

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

####
log "Creating configuration file: app-accelerator-values.yaml"

cat > "app-accelerator-values.yaml" <<EOF
server:
  service_type: "$SERVICE_TYPE"
  watched_namespace: "$DEV_NAMESPACE"
EOF

####
log "Creating configuration file: app-live-view-values.yaml"

cat > "app-live-view-values.yaml" <<EOF
---
connector_namespaces: [$DEV_NAMESPACE]
server_namespace: app-live-view
EOF

####
log "Creating configuration file: cnr-values.yaml"

cat > "cnr-values.yaml" <<EOF
---
$CNR_PROVIDER
EOF

####
log "Creating configuration file: default-supply-chain-values.yaml"

cat > "default-supply-chain-values.yaml" <<EOF
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
log "Creating configuration file: scst-sign-values.yaml"

cat > "scst-sign-values.yaml" <<EOF
---
warn_on_unmatched: true
EOF

####
log "Creating configuration file: app-live-view-values.yaml"

cat > "scst-store-values.yaml" <<EOF
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

####
log "Creating configuration file: imagepolicy-cosign.yaml"

cat > "imagepolicy-cosign.yaml" <<EOF
---

apiVersion: signing.run.tanzu.vmware.com/v1alpha1
kind: ClusterImagePolicy
metadata:
 name: image-policy
spec:
 verification:
   exclude:
     resources:
       namespaces:
       - kube-system
   keys:
   - name: cosign-key
     publicKey: |
       -----BEGIN PUBLIC KEY-----
       MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhyQCx0E9wQWSFI9ULGwy3BuRklnt
       IqozONbbdbqz11hlRJy9c7SG+hdcFl9jE9uE/dwtuwU2MqU9T/cN0YkWww==
       -----END PUBLIC KEY-----
   images:
   - namePattern: gcr.io/projectsigstore/cosign*
     keys:
     - name: cosign-key
EOF

####
log "Creating configuration file: metastore-rbac.yaml"
cat > "metastore-rbac.yaml" <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: metadata-store-read-write
  namespace: metadata-store
rules:
- resources: ["all"]
  verbs: ["get", "create", "update"]
  apiGroups: [ "metadata-store/v1" ]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: metadata-store-read-write
  namespace: metadata-store
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: metadata-store-read-write
subjects:
- kind: ServiceAccount
  name: metadata-store-read-write-client
  namespace: metadata-store

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metadata-store-read-write-client
  namespace: metadata-store
automountServiceAccountToken: false
EOF

####
log "Creating configuration file: dev-namespace-enable.yaml"
cat > "dev-namespace-enable.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: service-account # use value from "Install Default Supply Chain"
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: kapp-permissions
  annotations:
    kapp.k14s.io/change-group: "role"
rules:
  - apiGroups:
      - servicebinding.io
    resources: ['servicebindings']
    verbs: ['*']
  - apiGroups:
      - serving.knative.dev
    resources: ['services']
    verbs: ['*']
  - apiGroups: [""]
    resources: ['configmaps']
    verbs: ['get', 'watch', 'list', 'create', 'update', 'patch', 'delete']

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kapp-permissions
  annotations:
    kapp.k14s.io/change-rule: "upsert after upserting role"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kapp-permissions
subjects:
  - kind: ServiceAccount
    name: service-account # use value from "Install Default Supply Chain"
EOF
