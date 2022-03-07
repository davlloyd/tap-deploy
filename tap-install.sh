#! /bin/sh


# TAP Deployment Script
# Currently tested with Beta 2

echo "Installing Tanzu Application Platform"
echo "###"


#############################
# Before Running
#############################

#  1) Make sure cluster context is set to target cluster
#  2) Make sure target cluster is running k8s version releases 1.19, 1.20 or 1.21
#  3) Set your variables in the tap_env.sh. If password files not set then add values directly into the variables and keep the file varibales empty
#  4) install Carvel cli tools https://github.com/vmware-tanzu/carvel-kapp/releases (v0.42.0 tested with this script)
#  5) install Tanzu cli tool for your Mac/Linux machine https://github.com/pivotal/docs-tap/blob/main/install-general.md#prereqs (0.5.0 tested with this script)



function log() {
  echo "\n\xf0\x9f\x93\x9d     --> $*\n"
}


source tap.conf
source tap_managefiles.sh


function latestVersion() {
  tanzu package available list $1 -n tap-install -o json | jq -r 'sort_by(."released-at")[-1].version'
}

function installLatest() {
  local name=$1
  local package=$2
  local values=$3
  local timeout=${4:-10m}


  local version=$(latestVersion $package)
  
  installPackage $name $package $version $values $timeout
}

function installPackage() {
  local name=$1
  local package=$2
  local version=$3
  local values=$4
  local timeout=${5:-10m}

  tanzu package install \
    $name -p $package -v $version \
    -n tap-install \
    --poll-timeout $timeout \
    ${values:+-f} $values \

  validateInstall $name
}


function validateInstall(){
    status=$(tanzu package installed get $1 -n tap-install)
    if [[ $status == *"ReconcileSucceeded True"* ]]; then
      echo "Package $1 install succeeded \xE2\x9C\x94"
    else
      tanzu package installed get $1 -n tap-install
      echo "Package $1 install failed \xE2\x9D\x8C"
      if promptyn "Do you want to continue (Y/N)?"; then
        echo "Continuing..."
      else
        exit
      fi
    fi
}

function promptyn () {
    while true; do
        read -p "$1 " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}


shopt -s nocasematch
if [ "$TKG_CLUSTER" == "no" ]; then
  log "Installing pre-reqs"

  # Install KApp Controller
  log "Installing KApp Controller"
  kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/$KAPP_RELEASE/release.yml --yes

  # Install SecretGen Controller
  log "Installing SecretGen Controller"
  kapp deploy -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/$SECRETGEN_RELEASE/release.yml --yes
fi
shopt -u nocasematch


# Installing TAP packages
log "Install TAP Packages"

log "Setup for package deployment"

# Set destination install namespace
kubectl create namespace tap-install --dry-run=client -o yaml | kubectl apply -f -

# Set destination developer namespace
kubectl create namespace $DEV_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Pivnet access
log "Add Pivnet registry credentials"

CHECK=$(kubectl get secret -n tap-install tap-registry 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    tanzu secret registry add tap-registry \
        --username $PIVNET_ACCOUNT --password $PIVNET_PASSWORD \
        --server registry.tanzu.vmware.com \
        --export-to-all-namespaces --namespace tap-install --yes
else
    log "Secret already exists"
fi

# Add TAP Image Repository
log "Add TAP Image Repository"

CHECK=$(tanzu package repository get tanzu-tap-repository -n tap-install | wc -l)
if [ $CHECK -gt 1 ]; then
    tanzu package repository delete tanzu-tap-repository -n tap-install --yes
    while [ "$CHECK" -gt "1" ]
    do
      printf "."
      CHECK=$(tanzu package repository get tanzu-tap-repository -n tap-install | wc -l)
      sleep 1
    done
fi

tanzu package repository add tanzu-tap-repository \
    --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_RELEASE \
    --namespace tap-install

log "Validate Available packages"
CHECK=$(tanzu package available list --namespace tap-install | wc -l)
while [ "$CHECK" -le "2" ]
do
   printf "."
   CHECK=$(tanzu package available list --namespace tap-install | wc -l)
   sleep 1
done

echo "\n\nReady to install packages"
read -p "Press [Enter] key to continue"

log "Install TAP"
installPackage tap tap.tanzu.vmware.com $TAP_RELEASE tap-values.yml 60m


### Set namesapce for developer access and application deployment
log "Setup $DEV_NAMESPACE namespace for workloads"

log "Add internal registry credentials"

CHECK=$(kubectl get secret -n alpha registry-credentials 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    tanzu secret registry add registry-credentials \
        --username $REGISTRY_ACCOUNT \
        --password '$REGISTRY_PASSWORD' \
        --server $REGISTRY_HOST \
        --namespace $DEV_NAMESPACE
else
    log "Secret already exists"
fi


log "Set accounts and permissions"
kubectl -n $DEV_NAMESPACE apply -f dev-namespace-enable.yaml


# Finishing up

EXTERNAL_IP=$(kubectl get svc envoy -n tanzu-system-ingress -o json | jq -r '.status.loadBalancer.ingress[0].ip')


echo "\n---------------------------------------------------------------------------------\n"
echo "\n\xf0\x9f\x8e\x89  ***Install Completed***  \xf0\x9f\x98\x80\x0a\n\n"
echo "Wildcard Domain:       $CUSTOM_DOMAIN"
echo "Ingress External IP:   $EXTERNAL_IP for wildcard custom DNS domain"
echo "Developer Namespace:   $DEV_NAMESPACE"
echo "\n---------------------------------------------------------------------------------\n\n\n"
