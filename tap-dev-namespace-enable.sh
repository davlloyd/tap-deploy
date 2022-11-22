
function log() {
  echo "\n\xf0\x9f\x93\x9d     --> $*\n"
}



if [ -n "$1" ] && [ -n "$2" ]; then
  source tap.conf
  DEV_NAMESPACE=$1
  SOURCE_NAMESPACE=$2
  ### Set namesapce for developer access and application deployment
  log "Setup $DEV_NAMESPACE namespace for workloads, copy templates from $SOURCE_NAMESPACE"

  STORE_ACCESS_TOKEN=$(kubectl get secret $(kubectl get sa -n metadata-store metadata-store-read-client -o json | jq -r '.secrets[0].name') -n metadata-store -o json | jq -r '.data.token' | base64 -d)
  source tap_managefiles.sh
  

  log "Create $DEV_NAMESPACE namespace if it does not exist"
  kubectl create namespace $DEV_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

  log "Add internal registry credentials"

  CHECK=$(kubectl get secret -n $DEV_NAMESPACE registry-credentials 2>&1)
  if [[ $CHECK == *"NotFound"* ]]; then
      tanzu secret registry add registry-credentials \
          --username $REGISTRY_ACCOUNT \
          --password "$REGISTRY_PASSWORD" \
          --server $REGISTRY_HOST \
          --namespace $DEV_NAMESPACE
  else
      log "Secret already exists"
  fi


  log "Copy default scan templates"
  kubectl get scantemplate -n $SOURCE_NAMESPACE blob-source-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 
  kubectl get scantemplate -n $SOURCE_NAMESPACE private-image-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 
  kubectl get scantemplate -n $SOURCE_NAMESPACE public-image-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 
  kubectl get scantemplate -n $SOURCE_NAMESPACE public-source-scan-template -o yaml | sed "s/namespace: .*/namespace: $DEV_NAMESPACE/" | kubectl apply -n $DEV_NAMESPACE -f - 

  log "Set accounts and permissions"
  kubectl -n $DEV_NAMESPACE apply -f dev-namespace-enable.yaml

else
  log "No namespace value provided"
fi

