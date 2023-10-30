#!/usr/bin/env bash
set -eE

read -p "AWS access_key_id: " aws_access_key;
read -p "AWS secret_access_key: " -s aws_secret_key; 
echo " "
read -p "AWS session_token: " aws_access_token; 
export AWS_KEY=$aws_access_key;
export AWS_SECRET=$aws_secret_key;
export AWS_TOKEN=$aws_access_token;


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-secret
  namespace: crossplane-system
stringData:
  creds: |
    $(printf "[default]\n    aws_access_key_id = %s\n    aws_secret_access_key = %s\n    aws_session_token = %s\n" "${AWS_KEY}" "${AWS_SECRET}" "${AWS_TOKEN}")
EOF

cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: aws-config
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-secret
      key: creds
EOF

