
# Cleanup old secrets if they exist 
# Arg 1 = secret name
# Arg 2 = namespace name
function cleanSecret(){
    CHECK=$(kubectl get secret -n $2 $1 2>&1)
    if [[ $CHECK != *"NotFound"* ]]; then
        log "Cleanup old secret"
        kubectl delete secret  -n $2 $1  >null
    fi
}

# Add Pivnet access
# log "Add Pivnet registry credentials"

cleanSecret tap-registry tap-install
tanzu secret registry add tap-registry \
    --username $PIVNET_ACCOUNT \
    --password $PIVNET_PASSWORD \
    --server registry.tanzu.vmware.com \
    --namespace tap-install \
    --export-to-all-namespaces \
    --yes  > /dev/null 2>&1


# Add internal registry credentials
log "Add internal registry credentials"

cleanSecret registry-credentials tap-install
tanzu secret registry add registry-credentials \
    --username $REGISTRY_ACCOUNT \
    --password "$REGISTRY_PASSWORD" \
    --server $REGISTRY_HOST \
    --namespace tap-install \
    --export-to-all-namespaces \
    --yes > /dev/null 2>&1

# Add internal registry credentials
log "Add internal registry credentials for local proxy"

cleanSecret lsp-registry-credentials tap-install
tanzu secret registry add lsp-registry-credentials \
    --username $REGISTRY_ACCOUNT \
    --password "$REGISTRY_PASSWORD" \
    --server $REGISTRY_HOST \
    --namespace tap-install \
    --export-to-all-namespaces \
    --yes > /dev/null 2>&1



# Add git repo credentials
log "Add Git Repository credentials"

cleanSecret git-access tap-install
cleanSecret git-access tap-namespace-provisioning 
kubectl apply -n tap-install -f - << EOF > /dev/null 2>&1
    apiVersion: v1
    kind: Secret
    metadata:
        name: git-access
    type: Opaque
    stringData:
        username: $GITOPS_ACCOUNT
        password: $GIT_ACCESS_TOKEN
EOF



# Add ns configs
log "Add NS pinned configs"


# cleanSecret team-secret-store tap-install
# kubectl apply -n tap-install -f - << EOF > /dev/null 2>&1
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       name: team-secret-store
#     type: Opaque
#     stringData:
#         content.yaml: |
#             alpha:
#                 username: alphauser
#                 password: alphapass
#             beta:
#                 username: betaauser
#                 password: betaapass
#             charlie:
#                 username: charlieuser
#                 password: charliepass
#             delta:
#                 username: deltauser
#                 password: deltapass
# EOF    


# Add git repo credentials for namespace proviosing
log "Prep namespace provioner values"

cleanSecret git-auth tap-install
cleanSecret git-auth tap-namespace-provisioning 
kubectl apply -n tap-install -f - << EOF > /dev/null 2>&1
    apiVersion: v1
    kind: Secret
    metadata:
        name: git-auth
    type: Opaque
    stringData:
        content.yaml: |
            git:
                host: $GITOPS_SERVER
                username: $GITOPS_ACCOUNT
                password: $GIT_ACCESS_TOKEN
EOF


log "Add namespace provioner overlay"

cleanSecret git-auth-overlay tap-install
cleanSecret git-auth-overlay tap-namespace-provisioning 
kubectl apply -n tap-install -f - << EOF > /dev/null 2>&1
    apiVersion: v1
    kind: Secret
    metadata:
        name: git-auth-overlay
        namespace: tap-install
        annotations:
            kapp.k14s.io/change-rule: "delete after deleting tap"
    stringData:
        git-auth-overlay.yaml: |
            #@ load("@ytt:overlay", "overlay")
            #@overlay/match by=overlay.subset({"apiVersion": "v1", "kind": "ServiceAccount","metadata":{"name":"default"}}), expects="0+"
            ---
            secrets:
            #@overlay/append
            - name: git
EOF
