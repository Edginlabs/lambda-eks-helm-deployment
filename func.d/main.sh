#!/bin/bash -e
# set -euo pipefail

# pahud/lambda-layer-kubectl for Amazon EKS

# include the common-used shortcuts
source libs.sh

# env

# echo $1

# load .env.config cache and read previously used cluster_name
[ -f /tmp/.env.config ] && cat /tmp/.env.config && source /tmp/.env.config

# check if client has specified different cluster_name
input_cluster_name=$(echo $1 | jq -r '.cluster_name | select(type == "string")')
if [ -n "${input_cluster_name}" ]  && [ "${input_cluster_name}" != "${cluster_name}" ]; then
    echo "got new cluster_name=$input_cluster_name - update kubeconfig now..."
    update_kubeconfig "$input_cluster_name" || exit 1
    cluster_name="$input_cluster_name"
    echo "writing new cluster_name=${cluster_name} to /tmp/.env.config"
    echo "cluster_name=${cluster_name}" > /tmp/.env.config
fi

#
# Your business logic starts here
#
StackId=$(echo $1 | jq -r '.StackId | select(type == "string")')
ResponseURL=$(echo $1 | jq -r '.ResponseURL | select(type == "string")')
Repository=$(echo $1 | jq -r '.ResourceProperties.Repository | select(type == "string")')
Namespace=$(echo $1 | jq -r '.ResourceProperties.Namespace | select(type == "string")')
Timeout=$(echo $1 | jq -r '.ResourceProperties.Timeout | select(type == "string")')
Release=$(echo $1 | jq -r '.ResourceProperties.Release | select(type == "string")')
Chart=$(echo $1 | jq -r '.ResourceProperties.Chart | select(type == "string")')
RequestType=$(echo $1 | jq -r '.RequestType | select(type == "string")')
RequestId=$(echo $1 | jq -r '.RequestId | select(type == "string")')
ServiceToken=$(echo $1 | jq -r '.ServiceToken | select(type == "string")')
LogicalResourceId=$(echo $1 | jq -r '.LogicalResourceId | select(type == "string")')

sendResponseCurl(){
  # Usage: sendRespose body_file_name url
  curl -s -XPUT \
  -H "Content-Type: " \
  -d @$1 $2
}

helm_op(){
  echo "=> trying to apply the yaml..."
  # kubectl get pods
  /opt/helm/helm upgrade --install \
    --wait \
    --atomic \
    --repo=${Repository} \
    --namespace=${Namespace} \
    --timeout=${Timeout} \
    ${Release} \
    ${Chart}
}
helm_rem(){
  echo "=> removing helm chart..."
  /opt/helm/helm remove --namespace=${Namespace} ${Release}
}


sendResponseSuccess(){
  cat << EOF > /tmp/sendResponse.body.json
{
    "Status": "SUCCESS",
    "Reason": "",
    "PhysicalResourceId": "${RequestId}",
    "StackId": "${StackId}",
    "RequestId": "${RequestId}",
    "LogicalResourceId": "${LogicalResourceId}",
    "Data": {
        "Result": "OK"
    }
}
EOF
  echo "=> sending cfn custom resource callback"
  sendResponseCurl /tmp/sendResponse.body.json $ResponseURL
}

sendResponseFailed(){
  cat << EOF > /tmp/sendResponse.body.json
{
    "Status": "FAILED",
    "Reason": "",
    "PhysicalResourceId": "${RequestId}",
    "StackId": "${StackId}",
    "RequestId": "${RequestId}",
    "LogicalResourceId": "${LogicalResourceId}",
    "Data": {
        "Result": "OK"
    }
}
EOF
  echo "sending callback to $ResponseURL"
  sendResponseCurl /tmp/sendResponse.body.json $ResponseURL
}


case $RequestType in 
  "Create")
    helm_op
    sendResponseSuccess
  ;;
  "Delete")
    helm_rem
    sendResponseSuccess
  ;;
  "Update")
    helm_op
    sendResponseSuccess
  ;;
  *)
    sendResponseSuccess
  ;;
esac


exit 0