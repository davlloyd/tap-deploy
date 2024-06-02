

# Create configuration files for TAP Packages and a single package profile
# - app-accelerator-values.yaml
# - app-live-view-values.yaml
# - cnr-values.yaml
# - default-supply-chain-values.yaml
# - tbs-values.yaml


####
log "Create TAP Profile File"

cat > "tap-values.yml" <<EOF
profile: $PACKAGE_PROFILE
ceip_policy_disclosed: true 

supply_chain: $SUPPLY_CHAIN

shared:
  ingress_domain: $CUSTOM_DOMAIN
  ingress_issuer: "$SHARED_ISSUER"
  kubernetes_distribution: ""
  kubernetes_version: "$K8SMAJORVERSION.$K8SMINORVERSION"
  image_registry:
    project_path: "$REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_TBS"
    secret:
      name: registry-credentials
      namespace: tap-install
EOF



if [[ -f "$REGISTRY_CERTIFICATE_FILE" ]]; then
    log "Reading Registry certificate file $REGISTRY_CERTIFICATE_FILE"
    REGISTRY_CERTIFICATE=$(cat $REGISTRY_CERTIFICATE_FILE)
    log "Setup to use custom registry certificate"

    cat >> "tap-values.yml" <<EOF
  ca_cert_data: |
$REGISTRY_CERTIFICATE
EOF

fi

cat >> "tap-values.yml" <<EOF


buildservice:
  kp_default_repository: "$REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_TBS"
  kp_default_repository_secret:
    name: registry-credentials
    namespace: tap-install
  exclude_dependencies: $TBS_FULL_DEPENDENCIES    # Need to add logic to do post update of full packages if set to true


local_source_proxy:
  repository: "$REGISTRY_HOST/$REGISTRY_PROJECT/$REGISTRY_REPO_LOCALPROXY"
  push_secret:
    name: lsp-registry-credentials
    namespace: tap-install
    create_export: true


accelerator:
  ingress:
    include: true

metadata_store:
  ns_for_export_app_cert: "*"
  app_service_type: $SERVICE_TYPE


policy:
  tuf_enabled: false

grype:
  targetImagePullSecret: "registry-credentials"

cnrs:
  domain_name: "apps.$CUSTOM_DOMAIN"

tap_gui:
  metadataStoreAutoconfiguration: true
  service_type: "$SERVICE_TYPE"
  ingressEnabled: "true"
  ingressDomain: "$CUSTOM_DOMAIN"
  app_config:
    app:
      baseUrl: https://tap-gui.$CUSTOM_DOMAIN
    catalog:
      locations:
        - type: url
          target: $GIT_CATALOG_URL
      processors:
        appAccelerators:
          target: http://acc-server.accelerator-system.svc.cluster.local/api/accelerators
    reading:
      allow:
      - host: acc-server.accelerator-system.svc.cluster.local
    backend:
      baseUrl: https://tap-gui.$CUSTOM_DOMAIN
      cors:
        origin: https://tap-gui.$CUSTOM_DOMAIN
      #database:
      #  client: pg
      #  connection:
      #    host: "$PG_HOSTNAME"
      #    port: "5432"
      #    user: "$PG_USERNAME"
      #    password: "$PG_PASSWORD"
      #    ssl: "false"
    integrations:
      github:
        - host: github.com
          token: $GIT_ACCESS_TOKEN
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
          title: "Github Login"
          message: "Enter with your GitHub account"
    techdocs:
      builder: external
      generators:
        techdocs: docker
      publisher:
        type: $DOC_BUCKET_TYPE
        $DOC_BUCKET_TYPE:
          bucketName: $DOC_BUCKET
          bucketRootPath: '/'
          credentials:
            accessKeyId: $DOC_BUCKET_ACCESSID
            secretAccessKey: $DOC_BUCKET_SECRET
          endpoint: $DOC_BUCKET_ENDPOINT
EOF


if [ "$CERT_WILDCARD_ENABLED" == 1 ]; then
  log "Setup to use wildcard certificate"

cat >> "tap-values.yml" <<EOF
  tls:
    namespace: $CERT_WILDCARD_NAMESPACE
    secretName: $CERT_WILDCARD_SECRET

contour:
  envoy:
    service:
      type: $SERVICE_TYPE
  default_tls_secret: $CERT_WILDCARD_NAMESPACE/$CERT_WILDCARD_SECRET

EOF

else
  log "Wildcard certificate not used"

fi

if [ "$TMC_GITOPS_ENABLED" == 1 ]; then
  log "Prevent FluxCD and Cert-manager from being installed"

  cat >> "tap-values.yml" <<EOF

excluded_packages:
- fluxcd.source.controller.tanzu.vmware.com
- cert-manager.tanzu.vmware.com

EOF
fi

if [ "$GITOPS_ENABLED" == 1 ]; then
  log "Enable GitOps for supplychain"

  cat >> "tap-values.yml" <<EOF
namespace_provisioner:
  controller: false
  additional_sources:
  - git:
      ref: origin/main
      subPath: $GITOPS_NS_REPO_FOLDER_ADDITIONS
      url: $GITOPS_SERVER$GITOPS_OWNER/$GITOPS_NS_REPO.git
      secretRef:
        name: git-access
        namespace: tap-install
        create_export: true
    path: _ytt_lib/$GITOPS_NS_REPO_FOLDER_ADDITIONS-setup
  - git:
      ref: origin/main
      subPath: $GITOPS_NS_REPO_FOLDER_CREDENTIALS
      url: $GITOPS_SERVER$GITOPS_OWNER/$GITOPS_NS_REPO.git
    path: _ytt_lib/$GITOPS_NS_REPO_FOLDER_CREDENTIALS-setup
  gitops_install:
    ref: origin/main
    subPath: $GITOPS_NS_REPO_FOLDER_PROVISION
    url: $GITOPS_SERVER$GITOPS_OWNER/$GITOPS_NS_REPO.git
  import_data_values_secrets:
  - name: git-auth
    namespace: tap-install
    create_export: true
  # - name: team-secret-store
  #   namespace: tap-install
  #   create_export: true
  overlay_secrets:
  - name: git-auth-overlay
    namespace: tap-install
    create_export: true

$SUPPLY_CHAIN_CONFIG:
  #cluster_builder: default
  registry:
    server: "$REGISTRY_HOST"
    repository: "$REGISTRY_PROJECT/supply-chain"
  gitops:
    server_address: $GITOPS_SERVER
    repository_owner: $GITOPS_OWNER
    repository_name: $GITOPS_REPO
    ssh_secret: "git"
    branch: main
    commit_strategy: $GIT_COMMIT_STRATEGY
    pull_request:
      server_kind: github
      commit_branch: ""
      pull_request_title: "ready for review"
      pull_request_body: "generated by supply chain"
  git_implementation: libgit2   # default value go-git
EOF
else
  cat >> "tap-values.yml" <<EOF
namespace_provisioner:
  controller: true
  namespace_selector:
    matchExpressions:
    - key: apps.tanzu.vmware.com/tap-ns
      operator: Exists

$SUPPLY_CHAIN_CONFIG:
  #cluster_builder: default
  registry:
    server: "$REGISTRY_HOST"
    repository: "$REGISTRY_PROJECT/supply-chain"
EOF

fi


####
