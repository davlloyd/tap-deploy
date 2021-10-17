# TAP setup on GKE

## Step 1: Setup Cluster
1. Manual install of cluster not autopilot

2. Set to 5 nodes at t-shirt size e2-standard-4

3. Set version to 1.21 and disable auto upgrade

# Currently tested on GKE standard clusters with both GCR and DockerHub registries
# GKE Cluster setup
# - Deployment model standard
# - Target regional
# - Control plane version 'Static' 1.21.4-gke.2300
# - 3 zones, 3 nodes per zone
# - Disabled auto upgrade
# - Machine type e2-standard-2 (2vcpu, 8GB RAM, 100GB boot Disk)
# - Enable Kubernetes network policy
# - Enable Load Balancer

# Still to do
# - Make flexible between local deployments such as kind and cluster deployments
# - Still to test AKS, EKS, TKGm 1.4




#############################
# Before Running
#############################

#  1) Make sure cluster context is set to target cluster
#  2) Make sure target cluster is running k8s version releases 1.19, 1.20 or 1.21
#  3) Set your variables in the tap_env.sh. If password files not set then add values directly into the variables and keep the file varibales empty
#  4) install Carvel cli tools https://github.com/vmware-tanzu/carvel-kapp/releases (v0.42.0 tested with this script)
#  5) install Tanzu cli tool for your Mac/Linux machine https://github.com/pivotal/docs-tap/blob/main/install-general.md#prereqs (0.5.0 tested with this script)




## Step 2. pre-reqs
1. Install carvel kapp CLI tool release v0.42 from https://github.com/vmware-tanzu/carvel-kapp/releases

2. Install kapp controller
    > kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/v0.27.0/release.yml
    validate install with command
    > kubectl get deployment kapp-controller -n kapp-controller  -o yaml | grep kapp-controller.carvel.dev/version

3. Install secret gen controller
    > kapp deploy -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/v0.5.0/release.yml
    validate install with command
    > kubectl get pods -A | grep secretgen-controller

4. Install CertManager
    > kapp deploy -a cert-manager -f https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml

5. Install FluxCD Source-Controller
    > kubectl create namespace flux-system
    kubectl create clusterrolebinding default-admin --clusterrole=cluster-admin --serviceaccount=flux-system:default
    kapp deploy -a flux-source-controller -n flux-system \
    -f https://github.com/fluxcd/source-controller/releases/download/v0.15.4/source-controller.crds.yaml \
    -f https://github.com/fluxcd/source-controller/releases/download/v0.15.4/source-controller.deployment.yaml

## Step 3. Install the Tanzu CLI 
6. Install Tanzu CLI 0.5.0 from TAP source on Pivnet https://network.tanzu.vmware.com/products/tanzu-application-platform#/releases/967169/file_groups/5595 and follow the procedures to initialise the required plug-ins at at https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.2/tap-0-2/GUID-install-general.html#cli-and-plugin


## Step 4. Install Packages required for TAP
1. Create target namespace
    > kubectl create ns tap-install 

2. Create image pull secret with Pivnet account
    > tanzu imagepullsecret add tap-registry --username TANZU-NET-USER --password TANZU-NET-PASSWORD --registry registry.tanzu.vmware.com --export-to-all-namespaces --namespace tap-install

3. Add TAP package repository
    > tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:0.2.0 --namespace tap-install
   Install can be validated with command below. Should show status as **Reconcile Succeeded**
   > tanzu package repository get tanzu-tap-repository --namespace tap-install


4. Install packages
    - Install **CNR** with defautl values
        - As a follow on step run the following for each NS that you want to deploy into CNR if not deployed via supplychain
            > kubectl create secret generic pull-secret --from-literal=.dockerconfigjson={} --type=kubernetes.io/dockerconfigjson
            kubectl annotate secret pull-secret secretgen.carvel.dev/image-pull-secret=""
            kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "pull-secret"}]}'
    - Install **App Accelerator** with default values
    - Install **Convention Service** 
    - Install **Source Controller**
    - Install **Supply Chain Choreographer**
    - Install **Default Supply Chain**
        > tanzu imagepullsecret add registry-credentials --registry docker.io --username davlloyd --password B3ach8um! --export-to-all-namespaces --namespace tap-install
        - **storeg needs db changed in config**
        
    - Install **Developer Convcentions**
    - Install **Application Live View**
    - Install **Service Bindings**
    - Install **Supply Chain Security Tools**
    - Install **Supply Chain Security Tools - Sign**
        - Create Service account (different command for private registry as needs the creds secret)
        > cat <<EOF | kubectl apply -f -
        apiVersion: v1
        kind: ServiceAccount
        metadata:
        name: registry-credentials
        namespace: image-policy-system
        EOF
        - Create cluster image policy
        > cat <<EOF | kubectl apply -f -
        apiVersion: signing.run.tanzu.vmware.com/v1alpha1
        kind: ClusterImagePolicy
        metadata:
        name: image-policy
        spec:
        verification:
        exclude:
            resources:
            namespaces:
            - kube-system
        keys:
        - name: cosign-key
            publicKey: |
            -----BEGIN PUBLIC KEY-----
            MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhyQCx0E9wQWSFI9ULGwy3BuRklnt
            IqozONbbdbqz11hlRJy9c7SG+hdcFl9jE9uE/dwtuwU2MqU9T/cN0YkWww==
            -----END PUBLIC KEY-----
        images:
        - namePattern: gcr.io/projectsigstore/cosign*
            keys:
            - name: cosign-key
        EOF
    - Install **Supply Chain Security Tools - Scan**
      - Lots of steps, need to install scanners
    - Install **API portal**
    - Install **Services Control Plane (SCP) Toolkit**
    - Verify installed packages
      > tanzu package installed list --namespace tap-install

5. Enable Developer namespace for packages


tanzu package installed update default-supply-chain \
 --package-name default-supply-chain.tanzu.vmware.com \
 --version 0.2.0 \
 --namespace tap-install \
 --values-file default-supply-chain-values.yaml

tanzu package installed update metadata-store \
  --package-name scst-store.tanzu.vmware.com \
  --version 1.0.0-beta.0 \
  --namespace tap-install \
  --values-file scst-store-values.yaml



tanzu package install metadata-store \
  --package-name scst-store.tanzu.vmware.com \
  --version 1.0.0-beta.0 \
  --namespace tap-install \
  --values-file scst-store-values.yaml