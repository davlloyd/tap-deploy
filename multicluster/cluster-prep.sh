#! /bin/sh

kubectl apply -f - << EOF > /dev/null 2>&1
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
    - scantemplates
    verbs: ['get', 'watch', 'list']
    - apiGroups: ['app-scanning.apps.tanzu.vmware.com']
    resources:
    - imagevulnerabilityscans
    verbs: ['get', 'watch', 'list']
    - apiGroups: ['tekton.dev']
    resources:
    - taskruns
    - pipelineruns
    verbs: ['get', 'watch', 'list']
    - apiGroups: ['kappctrl.k14s.io']
    resources:
    - apps
    verbs: ['get', 'watch', 'list']
    - apiGroups: [ 'batch' ]
    resources: [ 'jobs', 'cronjobs' ]
    verbs: [ 'get', 'watch', 'list' ]
    - apiGroups: ['conventions.carto.run']
    resources:
    - podintents
    verbs: ['get', 'watch', 'list']
    - apiGroups: ['appliveview.apps.tanzu.vmware.com']
    resources:
    - resourceinspectiongrants
    verbs: ['get', 'watch', 'list', 'create']
    - apiGroups: ['apiextensions.k8s.io']
    resources: ['customresourcedefinitions']
    verbs: ['get', 'watch', 'list']
EOF

CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tap-gui-viewer
  namespace: tap-gui
  annotations:
    kubernetes.io/service-account.name: tap-gui-viewer
type: kubernetes.io/service-account-token
EOF

CLUSTER_TOKEN=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)

echo CLUSTER_URL: $CLUSTER_URL
echo CLUSTER_TOKEN: $CLUSTER_TOKEN

