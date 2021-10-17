# TAP setup on GKE

## Step 1: Setup Cluster
I have been using GKE as detailed below but k8s services comprised as:

- local (kind), TKG 1.4+, GKE, AKS, EKS cluster
- Version support is 1.19, 1.20 and 1.21 
- Network policies enabled

Also ensure the cluster context is set to target cluster

### 1.1 Steps for test GKE cluster as below
1. Manual install of cluster not autopilot
2. I target regional for availability but find 4 nodes of config e3-standard-2 or the like provides enough resources (2vcpu, 8GB RAM, 100GB disk per node)
3. Set version control to static, version 1.19, 1.20 or1.21
4. disable auto upgrade
5. Enable K8s Network Policy
6. Ensure Load Balancer is enabled

## Step 2: Set script variable values
Set your variables in the *tap_config.sh* file.
1. If password files not used such as with the GCR service account key file, then add values directly into the variables and keep the file variables empty
2. If a custom DNS domain is required for CNR then set the *CUSTOM_DOMAIN* variable. Leaving it empty will not set any value so will be knative default *welcome.com*
3. Set deployment model variable *'*DEPLOYMENT_MODEL* as either 'local' or 'cluster' to ensure that network services are corectly using either NodePort or LoadBalancer
4. Set a namespace target to be initially enabled for workloads

## Step 3: Install Carvel tools 
install Carvel cli tools <https://github.com/vmware-tanzu/carvel-kapp/releases>. Release *v0.42.0* tested with this script)

## Step 4. Install the Tanzu CLI 
Install Tanzu CLI 0.5.0 from TAP source on [Tanzu Network](https://network.tanzu.vmware.com/products/tanzu-application-platform#/releases/967169/file_groups/5595) and follow the procedures to initialise the required plug-ins at at [Tanzu CLI Install Instructions](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.2/tap-0-2/GUID-install-general.html#cli-and-plugin)


## Step 5. Install Packages required for TAP
Run script *sh ./tap-install.sh*

### Packages installed
- Cloud Native Runtimes
- App Accelerator
- Convention Service
- Source Controllers
- Supply Chain Choreographer
- Default Supply Chain
- Developer Convcentions
- Application Live View
- Service Bindings
- Supply Chain Security Tools
- Supply Chain Security Tools - Sign
- Supply Chain Security Tools - Scan
- API portal
- Services Control Plane (SCP) Toolkit

## Step 6. Some post deployment thoughts
You can add more namespaces ready for workloads by the following steps
1. Create Namespace
2. Set ImagePull secret with Tanzu CLI
3. Apply the Developer security artefect *dev-namespace-enable.yaml*
4. Edit the App Live view configuration file *app-live-view-values* and update package woth the command:
    tanzu package installed update app-live-view appliveview.tanzu.vmware.com app-live-view-values.yaml