
# Script creates a RO role for the metadata store and associated service 
# account for the TAP GUI to use to access the store.
# Required to provide CVE details in the GUI such as :
#
# - CVE voilation information


#function log() {
#  echo "\n\xf0\x9f\x93\x9d     --> $*\n"
#}


# Setup metastore readonly serviceaccount for k8s version <=23 
function setMetastoreSAk8s23(){
  log "Setting SA for k8s releases 1.23 and prior"
    kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: metadata-store-read-write
  namespace: metadata-store
rules:
- resources: ["all"]
  verbs: ["get", "create", "update"]
  apiGroups: [ "metadata-store/v1" ]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: metadata-store-read-write
  namespace: metadata-store
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: metadata-store-read-write
subjects:
- kind: ServiceAccount
  name: metadata-store-read-write-client
  namespace: metadata-store

---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: metadata-store-read-write-client
  namespace: metadata-store
  annotations:
    kapp.k14s.io/change-group: "metadata-store.apps.tanzu.vmware.com/service-account"
automountServiceAccountToken: false


EOF
}

# Setup metastore readonly serviceaccount for k8s version >=24
function setMetastoreSAk8s24(){
    log "Setting SA for k8s releases 1.24 and after"

kubectl apply -f - -o yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: metadata-store-read-write
  namespace: metadata-store
rules:
- resources: ["all"]
  verbs: ["get", "create", "update"]
  apiGroups: [ "metadata-store/v1" ]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: metadata-store-read-write
  namespace: metadata-store
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: metadata-store-read-write
subjects:
- kind: ServiceAccount
  name: metadata-store-read-write-client
  namespace: metadata-store

---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: metadata-store-read-write-client
  namespace: metadata-store
  annotations:
    kapp.k14s.io/change-group: "metadata-store.apps.tanzu.vmware.com/service-account"
automountServiceAccountToken: false

---

apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: metadata-store-read-write-client
  namespace: metadata-store
  annotations:
    kapp.k14s.io/change-rule: "upsert after upserting metadata-store.apps.tanzu.vmware.com/service-account"
    kubernetes.io/service-account.name: "metadata-store-read-write-client"

EOF

}

K8SVERSION=$(kubectl version -o json | jq -r '.serverVersion.minor')
log "K8s Version: $K8SVERSION"
kubectl create namespace metadata-store --dry-run=client -o yaml | kubectl apply -f -

log "Setting Metastore RO SA Account"
if [ $((K8SVERSION)) -ge 24 ]; then
  setMetastoreSAk8s24
  STORE_ACCESS_TOKEN=$(kubectl get secret metadata-store-read-write-client -n metadata-store -o json | jq -r '.data.token' | base64 -d)
else
  setMetastoreSAk8s23
  STORE_ACCESS_TOKEN=$(kubectl get secret $(kubectl get sa -n metadata-store metadata-store-read-write-client -o json | jq -r '.secrets[0].name') -n metadata-store -o json | jq -r '.data.token' | base64 -d)
fi


