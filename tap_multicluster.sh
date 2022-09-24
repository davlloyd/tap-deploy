####
log "Creating RBAC file for TAP GUI file: tap-gui-viewer-service-account-rbac.yaml."
cat > "tap-gui-viewer-service-account-rbac.yaml" <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: tap-gui
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: tap-gui
  name: tap-gui-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-gui-read-k8s
subjects:
  - kind: ServiceAccount
  namespace: tap-gui
  name: tap-gui-viewer
roleRef:
  kind: ClusterRole
  name: k8s-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-reader
rules:
  - apiGroups: ['']
    resources: ['pods', 'pods/log', 'services', 'configmaps', 'limitranges']
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['metrics.k8s.io']
    resources: ['pods']
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['apps']
    resources: ['deployments', 'replicasets', 'statefulsets', 'daemonsets']
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['autoscaling']
    resources: ['horizontalpodautoscalers']
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['networking.k8s.io']
    resources: ['ingresses']
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['networking.internal.knative.dev']
    resources: ['serverlessservices']
    verbs: ['get', 'watch', 'list']
  - apiGroups: [ 'autoscaling.internal.knative.dev' ]
    resources: [ 'podautoscalers' ]
    verbs: [ 'get', 'watch', 'list' ]
  - apiGroups: ['serving.knative.dev']
    resources:
    - configurations
    - revisions
    - routes
    - services
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['carto.run']
    resources:
    - clusterconfigtemplates
    - clusterdeliveries
    - clusterdeploymenttemplates
    - clusterimagetemplates
    - clusterruntemplates
    - clustersourcetemplates
    - clustersupplychains
    - clustertemplates
    - deliverables
    - runnables
    - workloads
      verbs: ['get', 'watch', 'list']
  - apiGroups: ['source.toolkit.fluxcd.io']
    resources:
    - gitrepositories
      verbs: ['get', 'watch', 'list']
  - apiGroups: ['source.apps.tanzu.vmware.com']
    resources:
    - imagerepositories
    - mavenartifacts
    verbs: ['get', 'watch', 'list']
    - apiGroups: ['conventions.apps.tanzu.vmware.com']
    resources:
    - podintents
    verbs: ['get', 'watch', 'list']
    - apiGroups: ['kpack.io']
    resources:
    - images
    - builds
    verbs: ['get', 'watch', 'list']
  - apiGroups: ['scanning.apps.tanzu.vmware.com']
  resources:
  - sourcescans
  - imagescans
  - scanpolicies
  verbs: ['get', 'watch', 'list']
  - apiGroups: ['tekton.dev']
  resources:
  - taskruns
  - pipelineruns
  verbs: ['get', 'watch', 'list']
  - apiGroups: ['kappctrl.k14s.io']
  resources:
  - apps
  Tanzu Application Platform v1.3
  VMware, Inc 751
  draft
  verbs: ['get', 'watch', 'list']
  - apiGroups: [ 'batch' ]
  resources: [ 'jobs', 'cronjobs' ]
  verbs: [ 'get', 'watch', 'list' ]

EOF


####
log "Creating Backstage demo group and account"
cat > "tap-gui-account.yaml" <<EOF

apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: surfer-dude
spec:
  profile:
    displayName: Surfer Dude
    email: user@surferslookout.com
    picture: https://icons.iconarchive.com/icons/sonya/swarm/256/Surfer-icon.png?background=%23fff
  memberOf: [surfer-team]

---

apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: surfer-team
  description: Surfers Lookout Team
spec:
  type: team
  profile:
    displayName: Surfers Team
    email: team-a@surferslookout.com
    picture: https://cdn-icons-png.flaticon.com/512/4579/4579737.png?background=%23fff
  parent: default-org
  children: []

EOF
