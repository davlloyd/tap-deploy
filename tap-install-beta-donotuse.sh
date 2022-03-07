#! /bin/sh


# TAP Deployment Script
# Currently tested with 1.0.1

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


log "Installing pre-reqs"


#####################
# Need to write logic to Download and install tanzu cluster essentials if not a TKG cluster
#####################


# Install KApp Controller
log "Installing KApp Controller"
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/$KAPP_RELEASE/release.yml --yes

# Install SecretGen Controller
log "Installing SecretGen Controller"
kapp deploy -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/$SECRETGEN_RELEASE/release.yml --yes

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

log "Add TAP Image Repository"
# Add TAP Image Repository

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

installPackage tap tap.tanzu.vmware.com 
tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values.yml -n tap-install

log "Install-Cert-Manager"

CERT_VERSION=$(latestVersion "cert-manager.tanzu.vmware.com")
kubectl apply -f cert-manager-rbac.yml 

cat <<EOF | kubectl apply -f -
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: cert-manager
  namespace: tap-install
spec:
  serviceAccountName: cert-manager-tap-install-sa
  packageRef:
    refName: cert-manager.tanzu.vmware.com
    versionSelection:
      constraints: "$CERT_VERSION"
      prereleases: {}
EOF

validateInstall "cert-manager"


log "Install CNR"
installLatest cloud-native-runtimes cnrs.tanzu.vmware.com cnr-values.yaml 30m

if [ ! -z "$CUSTOM_DOMAIN" ]; then
  log "Configure CNR domain domain: $CUSTOM_DOMAIN"
  kubectl apply -f cnr-custom-domain.yaml
fi

log "Set default namespace to run CNR"
#kubectl create secret generic pull-secret --from-literal=.dockerconfigjson={} --type=kubernetes.io/dockerconfigjson --dry-run -o yaml | kubectl apply -f -
#kubectl annotate secret pull-secret secretgen.carvel.dev/image-pull-secret=""

log "Install Convention Service"
installLatest convention-controller controller.conventions.apps.tanzu.vmware.com

log "Install Source Controller"
installLatest source-controller controller.source.apps.tanzu.vmware.com

log "Install Application Accelerator"
installLatest app-accelerator accelerator.apps.tanzu.vmware.com app-accelerator-values.yaml

log "Install Tanzu Build Service"
installLatest tbs buildservice.tanzu.vmware.com tbs-values.yaml 30m

log "Install Supply Chain Choreographer"
installLatest cartographer cartographer.tanzu.vmware.com

log "Install Out of the box Templates"
installLatest ootb-templates ootb-templates.tanzu.vmware.com

log "Install Default Supply Chain"
installLatest ootb-supply-chain-basic ootb-supply-chain-basic.tanzu.vmware.com ootb-supply-chain-values.yaml

log "Install Developer Conventions"
installLatest developer-conventions developer-conventions.tanzu.vmware.com

log "Install Spring Boot Conventions"
installLatest spring-boot-conventions spring-boot-conventions.tanzu.vmware.com

log "Install Application Live View"
kubectl create namespace app-live-view --dry-run=client -o yaml | kubectl apply -f -
installLatest app-live-view appliveview.tanzu.vmware.com app-live-view-values.yaml

CNR_EXTERNAL_IP=$(kubectl get svc -n contour-external envoy -o json | jq -r '.status.loadBalancer.ingress[0].ip')
GUI_PORT="443"

log "Install Tanzu Appklication Platform GUI"
log "Creating configuration file: tap-gui-values.yaml"
cat > "tap-gui-values.yaml" <<EOF
namespace: tap-gui
service_type: $SERVICE_TYPE
app_config:
  app:
    baseUrl: https://$CNR_EXTERNAL_IP:$GUI_PORT
  integrations:
    gitlab: # Other integrations available
      - host: $GIT_HOST
        apiBaseUrl: https://$GIT_HOST/api/v4
        token: $GIT_ACCESS_TOKEN
  catalog:
    locations:
      - type: url
        target: $GIT_CATALOG/catalog-info.yaml
  backend:
      baseUrl: https://$CNR_EXTERNAL_IP:$GUI_PORT
      cors:
          origin: https://$CNR_EXTERNAL_IP:$GUI_PORT
EOF

installLatest tap-gui tap-gui.tanzu.vmware.com

#log "Install Learning Center"
#installLatest learning-center learningcenter.tanzu.vmware.com learning-center-config.yaml

log "Install Service Bindings"
installLatest service-bindings service-bindings.labs.vmware.com

log "Install Supply Chain Security Tools - Store"
installLatest metadata-store scst-store.tanzu.vmware.com scst-store-values.yaml

log "Install Supply Chain Security Tools - Sign"
installLatest image-policy-webhook image-policy-webhook.signing.run.tanzu.vmware.com scst-sign-values.yaml


log "Create Image policy"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: registry-credentials
  namespace: image-policy-system
EOF

kubectl apply -f imagepolicy-cosign.yaml

log "Install Supply Chain Security Tools - Scan"

kubectl create namespace scan-link-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic metadata-store-ca -n scan-link-system --from-file=ca.crt=<(kubectl get secret app-tls-cert -n metadata-store -o json | jq -r '.data."ca.crt"' | base64 -d)

log "Apply Metastore security RBAC"
kubectl apply -f metastore-rbac.yaml

log "Apply Metastore security Auth"
META_URL=$(kubectl -n metadata-store get service -o name | grep app | xargs kubectl -n metadata-store get -o jsonpath='{.spec.ports[].name}{"://"}{.metadata.name}{"."}{.metadata.namespace}{".svc.cluster.local:"}{.spec.ports[].port}')
#META_CA=$(kubectl get secret app-tls-cert -n metadata-store -o json | jq -r '.data."ca.crt"' | base64 -d | sed  's/^/  /')
#META_SECRET_NAME=$(kubectl get sa -n metadata-store metadata-store-read-write-client -o json | jq -r '.secrets[0].name')
#META_TOKEN=$(kubectl get secret $META_SECRET_NAME -n metadata-store -o json | jq -r '.data.token' | base64 -d)

echo "---\nmetadataStoreUrl: $META_URL\nmetadataStoreCaSecret: metadata-store-ca\nmetadataStoreClusterRole: metadata-store-read-write" > scst-scan-controller-values.yaml

log "install Supply Chain Security Tools - Scan Controller"
installLatest scan-controller scanning.apps.tanzu.vmware.com scst-scan-controller-values.yaml

log "install Supply Chain Security Tools - Scan (Grype Scanner)"
installLatest grype-scanner grype.scanning.apps.tanzu.vmware.com

log "Install API portal"
installLatest api-portal api-portal.tanzu.vmware.com

log "Install Services Control Plane (SCP) Toolkit"
installLatest services-toolkit services-toolkit.tanzu.vmware.com

log "Setup $DEV_NAMESPACE namespace for workloads"

log "Add internal registry credentials"

CHECK=$(kubectl get secret -n $DEV_NAMESPACE registry-credentials 2>&1)
if [[ $CHECK == *"NotFound"* ]]; then
    tanzu secret registry add registry-credentials \
        --registry $REGISTRY_HOST \
        --username $REGISTRY_ACCOUNT \
        --password "$REGISTRY_PASSWORD"  \
        --namespace $DEV_NAMESPACE
else
    log "Secret already exists"
fi

log "Set accounts and permissions"
kubectl -n $DEV_NAMESPACE apply -f dev-namespace-enable.yaml



# Finishing up
CNR_EXTERNAL_IP=$(kubectl get svc -n contour-external envoy -o json | jq -r '.status.loadBalancer.ingress[0].ip')
ACC_EXTERNAL_IP=$(kubectl get svc -n accelerator-system acc-ui-server -o json | jq -r '.status.loadBalancer.ingress[0].ip')
ALV_EXTERNAL_IP=$(kubectl get svc -n app-live-view application-live-view-5112 -o json | jq -r '.status.loadBalancer.ingress[0].ip')


echo "\n---------------------------------------------------------------------------------\n"
echo "\n\xf0\x9f\x8e\x89  ***Install Completed***  \xf0\x9f\x98\x80\x0a\n\n"
echo "Cloud Native Runtimes External IP: $CNR_EXTERNAL_IP for wildcard custom DNS domain"
echo "Application Accelerator UI IP: $ACC_EXTERNAL_IP access at http://$ACC_EXTERNAL_IP"
echo "Application Live View UI IP: $ALV_EXTERNAL_IP access at http://$ALV_EXTERNAL_IP:5112"
echo "\n---------------------------------------------------------------------------------\n\n\n"