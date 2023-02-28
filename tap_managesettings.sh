

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
log "Setting LB Type"
if [ "$DEPLOYMENT_MODEL" == "cluster" ]; then
    SERVICE_TYPE="LoadBalancer"
    CNR_PROVIDER=""
else
    SERVICE_TYPE="NodePort"
    CNR_PROVIDER="provider: local"
fi


log "Setting Supplychain"
if [ "$SUPPLY_CHAIN" == "testing" ]; then
    SUPPLY_CHAIN_CONFIG="ootb_supply_chain_testing"
elif [ "$SUPPLY_CHAIN" == "testing_scanning" ]; then
    SUPPLY_CHAIN_CONFIG="ootb_supply_chain_testing_scanning"
else
    SUPPLY_CHAIN_CONFIG="ootb_supply_chain_basic"
fi
shopt -u nocasematch

log "Setting GitOps Values"
if [ "$GITOPS_ENABLED" == 1 ]; then
    CONTROLLER_NOGITOPS=false
else
    CONTROLLER_NOGITOPS=true
fi

