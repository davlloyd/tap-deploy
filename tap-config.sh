
# Target Application Platform version for package syncing
# TAP_RELEASE=
TAP_RELEASE=0.2.0

# Set deployment target type of 'local' for models such as kind or 'cluster' for TKG, GKE, etc
# DEPLOYMENT_MODEL=
DEPLOYMENT_MODEL=cluster

# Public registry access details
# Registry host name e.g. us.gcr.io
# REGISTRY_HOST=
REGISTRY_HOST=us.gcr.io

# Registry project name (e.g. user accopunt name in Dockerhub)
# REGISTRY_PROJECT=
REGISTRY_PROJECT=lloyd-266015

# Registry account name (e.g. in gcr it is _json_key but in Harbor or dockerhub it is your account name)
# REGISTRY_ACCOUNT=
REGISTRY_ACCOUNT=_json_key

# file path that contains the registry password or access key. 
# REGISTRY_PASSWORD_FILE=
REGISTRY_PASSWORD_FILE=~/gcr.json

# registry password 
# REGISTRY_PASSWORD=
REGISTRY_PASSWORD=

# Repsoitory that all build service images are uploaded into
# REGISTRY_REPO_TBS=
REGISTRY_REPO_TBS=build-service

# Pivotal Network access credentials. This is used to download the source packages
# PIVNET_ACCOUNT=
# PIVNET_PASSWORD_FILE=
# PIVNET_PASSWORD=
PIVNET_ACCOUNT=lloydd@vmware.com
PIVNET_PASSWORD_FILE=~/pivnet.txt
PIVNET_PASSWORD=

# Set custom DNS domain value for CNR. Domain DNS wild card to CNR External IP required
# CUSTOM_DOMAIN=
CUSTOM_DOMAIN=

# Namespace to enable for workload deployment via the default supply chain
# DEV_NAMESPACE=
DEV_NAMESPACE=alpha

# Allows you to set if you want to install Tekton with TAP. Tekton is used for the "default supply chain testing" which is not installed by default
# INSTALL_TEKTON=
INSTALL_TEKTON=true

