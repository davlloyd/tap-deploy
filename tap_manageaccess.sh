
# Add Pivnet access
log "Add Pivnet registry credentials"

CHECK=$(kubectl get secret -n tap-install tap-registry 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    tanzu secret registry add tap-registry \
        --username $PIVNET_ACCOUNT --password $PIVNET_PASSWORD \
        --server registry.tanzu.vmware.com \
        --export-to-all-namespaces --namespace tap-install --yes > /dev/null 2>&1
else
    log "Secret already exists"
fi

# Add internal registry credentials
log "Add internal registry credentials"

CHECK=$(kubectl get secret -n tap-install registry-credentials 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    tanzu secret registry add registry-credentials \
        --username $REGISTRY_ACCOUNT \
        --password "$REGISTRY_PASSWORD" \
        --server $REGISTRY_HOST \
        --namespace tap-install \
        --export-to-all-namespaces \
        --yes 
else
    log "Secret already exists"
fi


# Add git repo credentials
log "Add Git Repository credentials"

CHECK=$(kubectl get secret -n tap-install git-access 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    kubectl apply -n tap-install -f - << EOF
      apiVersion: v1
      kind: Secret
      metadata:
        name: git-access
        annotations:
          tekton.dev/git-0: $GITOPS_SERVER
      type: kubernetes.io/basic-auth 
      stringData:
        username: $GITOPS_OWNER
        password: $GIT_ACCESS_TOKEN
EOF
else
    log "Secret already exists"
fi


# Add git repo credentials
log "Add Git repository credentials"

CHECK=$(kubectl get secret -n tap-install git-auth 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    cat << EOF | kubectl apply -f -
    apiVersion: v1
    kind: Secret
    metadata:
      name: git-auth
      namespace: tap-install
    type: Opaque
    stringData:
      content.yaml: |
        git:
        host: $GITOPS_SERVER
        username: $GITOPS_OWNER
        password: $GIT_ACCESS_TOKEN
EOF
else
    log "Secret already exists"
fi


# Prep namespace secret controls

CHECK=$(kubectl get secret -n tap-install git-auth-overlay 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then

  cat << EOF | kubectl apply -f -
    apiVersion: v1
    kind: Secret
    metadata:
      name: git-auth-overlay
      namespace: tap-install
      annotations:
        kapp.k14s.io/change-rule: "delete after deleting tap"
    stringData:
      workload-git-auth-overlay.yaml: |
        #@ load("@ytt:overlay", "overlay")
        #@overlay/match by=overlay.subset({"apiVersion": "v1", "kind": "ServiceAccount","metadata":{"name":"default"}}), expects="0+"
        ---
        secrets:
        #@overlay/append
        - name: git
EOF
else
    log "Secret already exists"
fi
