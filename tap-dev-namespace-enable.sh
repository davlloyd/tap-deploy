
function log() {
  echo "\n\xf0\x9f\x93\x9d     --> $*\n"
}



if [ -n "$1" ]; then
  source tap.conf
  #source tap_managefiles.sh

  DEV_NAMESPACE=$1
  ### Set namesapce for developer access and application deployment
  log "Setup $DEV_NAMESPACE namespace for workloads"

  log "Create $DEV_NAMESPACE namespace if it does not exist"
  kubectl create namespace $DEV_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

  log "Add internal registry credentials"

  CHECK=$(kubectl get secret -n $DEV_NAMESPACE registry-credentials 2>&1)
  if [[ $CHECK == *"NotFound"* ]]; then
      log "Creating new secret"
      tanzu secret registry add registry-credentials \
          --username $REGISTRY_ACCOUNT \
          --password "$REGISTRY_PASSWORD" \
          --server $REGISTRY_HOST \
          -n $DEV_NAMESPACE
  else
      log "Secret already exists"
  fi


  log "Set accounts and permissions"
  kubectl -n $DEV_NAMESPACE apply -f dev-namespace-enable.yaml

else
  log "No namespace value provided"
fi

