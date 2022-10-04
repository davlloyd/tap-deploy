

# Create configuration files for TAP Packages and a single package profile
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

    if [[ -f "$GIT_ACCESS_TOKEN_FILE" ]]; then
        log "Reading Git access token file $GIT_ACCESS_TOKEN_FILE"
        GIT_ACCESS_TOKEN=$(cat $GIT_ACCESS_TOKEN_FILE)
    else
      log "No Git access token file defined so using GIT_ACCESS_TOKEN variable value"
    fi

    if [[ -f "$GIT_AUTH_CLIENTID_FILE" ]]; then
        log "Reading Git auth access token file $GIT_AUTH_CLIENTID_FILE"
        GIT_AUTH_CLIENTID=$(cat $GIT_AUTH_CLIENTID_FILE)
    else
      log "No Git clientid file defined so using GIT_AUTH_CLIENTID variable value"
    fi

    if [[ -f "$GIT_AUTH_SECRET_FILE" ]]; then
        log "Reading Git app auth secretfile $GIT_AUTH_SECRET_FILE"
        GIT_AUTH_SECRET=$(cat $GIT_AUTH_SECRET_FILE)
    else
      log "No Git auth secret file defined so using GIT_AUTH_SECRET variable value"
    fi

    if [[ -f "$DOC_BUCKET_CRED_FILE" ]]; then
        log "Reading Storgae bucket credential file $DOC_BUCKET_CRED_FILE"
        DOC_BUCKET_CRED=$(cat $DOC_BUCKET_CRED_FILE)
    else
      log "No Storage bucket credentials file so using DOC_BUCKET_CRED variable value"
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
log "Create TAP Profile File"

cat > "tap-values.yml" <<EOF
profile: $PACKAGE_PROFILE
ceip_policy_disclosed: true 

supply_chain: $SUPPLY_CHAIN


shared:
  ingress_domain: $CUSTOM_DOMAIN
  image_registry:
    project_path: "$REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_TBS"
    username: "$REGISTRY_ACCOUNT"
    password: '$REGISTRY_PASSWORD'


ootb_supply_chain_basic:
  #cluster_builder: default
  registry:
    server: "$REGISTRY_HOST"
    repository: "$REGISTRY_PROJECT/supply-chain"
  gitops:
    gitops.server_address: $GITOPS_SERVER
    gitops.repository_owner: $GITOPS_OWNER
    gitops.repository_name: $GITOPS_REPO
    ssh_secret: ""

ootb_supply_chain_testing:
  #cluster_builder: default
  registry:
    server: "$REGISTRY_HOST"
    repository: "$REGISTRY_PROJECT/supply-chain"
  gitops:
    gitops.server_address: $GITOPS_SERVER
    gitops.repository_owner: $GITOPS_OWNER
    gitops.repository_name: $GITOPS_REPO
    ssh_secret: ""

ootb_supply_chain_testing_scanning:
  #cluster_builder: default
  registry:
    server: "$REGISTRY_HOST"
    repository: "$REGISTRY_PROJECT/supply-chain"
  gitops:
    gitops.server_address: $GITOPS_SERVER
    gitops.repository_owner: $GITOPS_OWNER
    gitops.repository_name: $GITOPS_REPO
    ssh_secret: ""


contour:
  envoy:
    service:
      type: $SERVICE_TYPE


shared:
  kubernetes_distribution: ""


buildservice:
  kp_default_repository: "$REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_TBS"
  kp_default_repository_username: "$REGISTRY_ACCOUNT"
  kp_default_repository_password: '$REGISTRY_PASSWORD'
  #extras start below
  #exclude_dependencies: false    # Need to add logic to do post update of full packages if set to true
  descriptor_name: "$DESCRIPTOR_NAME"
  enable_automatic_dependency_updates: true
  tanzunet_username: "$PIVNET_ACCOUNT"
  tanzunet_password: "$PIVNET_PASSWORD"
  

tap_gui:
  service_type: "$SERVICE_TYPE"
  ingressEnabled: "true"
  ingressDomain: "$CUSTOM_DOMAIN"
  app_config:
    app:
      baseUrl: http://tap-gui.$CUSTOM_DOMAIN
    catalog:
      locations:
        - type: url
          target: $GIT_CATALOG_URL
    backend:
      baseUrl: http://tap-gui.$CUSTOM_DOMAIN
      cors:
        origin: http://tap-gui.$CUSTOM_DOMAIN
    integrations:
      github:
        - host: github.com
          token: $GIT_ACCESS_TOKEN
    proxy:
      /metadata-store:
        target: https://metadata-store-app.metadata-store:8443/api/v1
        changeOrigin: true
        secure: false
        headers:
          Authorization: "Bearer $STORE_ACCESS_TOKEN"
          X-Custom-Source: project-star 
    auth:
      allowGuestAccess: true
      environment: development
      providers:
        github:
          development:
            clientId: $GIT_AUTH_CLIENTID
            clientSecret: $GIT_AUTH_SECRET
            prompt: auto
      loginPage:
        github:
          title: Github Login
          message: Enter with your GitHub account
    techdocs:
      builder: 'external'
      generators:
        techdocs: 'docker'
      publisher:
        type: 'googleGcs'
        googleGcs:
          bucketName: $DOC_BUCKET
          credentials: $DOC_BUCKET_CRED'


metadata_store:
  ns_for_export_app_cert: "$DEV_NAMESPACE"
  app_service_type: $SERVICE_TYPE
  ingressDomain: "$CUSTOM_DOMAIN"
  ingress_enabled: "true"


scanning:
  metadataStore:
    url: ""

grype:
  targetImagePullSecret: "registry-credentials"
  namespace: "$DEV_NAMESPACE"


learningcenter:
  ingressDomain: "learningcenter.$CUSTOM_DOMAIN"


cnrs:
  domain_name: "apps.$CUSTOM_DOMAIN"


EOF


####
log "Creating configuration file: dev-namespace-enable.yaml"
cat > "dev-namespace-enable.yaml" <<EOF
---

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
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default

---
EOF


####
