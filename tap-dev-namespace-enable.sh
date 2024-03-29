#! /bin/sh


# TAP Dev namespace enablement Script

function log() {
  echo "\n\xf0\x9f\x93\x9d     --> $*\n"
}

source tap.conf
source tap_managesettings.sh

# Modified to support the namespace provisioner in 1.4

#if [ -n "$1" ] && [ -n "$2" ]; then
if [ -n "$1" ]; then
  DEV_NAMESPACE=$1
  #SOURCE_NAMESPACE=$2
  ### Set namesapce for developer access and application deployment
  #log "Setup $DEV_NAMESPACE namespace for workloads, copy templates from $SOURCE_NAMESPACE"

  #STORE_ACCESS_TOKEN=$(kubectl get secret $(kubectl get sa -n metadata-store metadata-store-read-client -o json | jq -r '.secrets[0].name') -n metadata-store -o json | jq -r '.data.token' | base64 -d)
  
  log "Setup $DEV_NAMESPACE namespace for workloads"

  log "Create $DEV_NAMESPACE namespace if it does not exist"
  kubectl create namespace $DEV_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

  log "Add internal registry credentials"

  CHECK=$(kubectl get secret -n $DEV_NAMESPACE registry-credentials 2>&1)
  if [[ $CHECK == *"NotFound"* ]]; then
      tanzu secret registry add registry-credentials \
          --username $REGISTRY_ACCOUNT \
          --password "$REGISTRY_PASSWORD" \
          --server $REGISTRY_HOST \
          --namespace $DEV_NAMESPACE \
          --yes 
  else
      log "Secret already exists"
  fi


  #log "Copy default scan templates"
  #kubectl get scantemplate -n $SOURCE_NAMESPACE blob-source-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 
  #kubectl get scantemplate -n $SOURCE_NAMESPACE private-image-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 
  #kubectl get scantemplate -n $SOURCE_NAMESPACE public-image-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 
  #kubectl get scantemplate -n $SOURCE_NAMESPACE public-source-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 

  #log "Set accounts and permissions"
  #kubectl -n $DEV_NAMESPACE apply -f dev-namespace-enable.yaml

  log "Enabled namespace"
  kubectl label namespaces $DEV_NAMESPACE apps.tanzu.vmware.com/tap-ns=""

else
  log "No namespace value provided"
fi


####
log "Creating configuration file: dev-namespace-enable.yaml"
cat > "dev-namespace-enable.yaml" <<EOF

---

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
  - name: git-access
  - name: tap-registry
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
