#!/usr/bin/env bash

# I have both helm2 and helm3 in my PATH, so this variable is to change the binary version in this script easily.
HELM_BINARY_NAME=helm3

function validate_setup() {
  PACKAGES="kubectl ${HELM_BINARY_NAME} jq"
  for i in ${PACKAGES}; do
    if [[ -z "$(which "${i}")" ]]; then
      echo "Please install ${i} and try again."
      exit 1
    fi
  done

  HELM_VERSION=$($HELM_BINARY_NAME version --short)
  if [[ $HELM_VERSION != v3* ]]; then
    echo "Helm version 3 is required to install the chart. Please install it and try again."
    echo "Current version Helm is ${HELM_VERSION}"
    exit 2
  fi
}

function get_kubectl_context() {
    kubectl config current-context
}

function get_kubectl_namespace() {
  kubectl config view --minify --output 'jsonpath={..namespace}'
}

function get_service() {
    kubectl get --namespace "${get_kubectl_namespace}" svc "${CHART_NAME}"  -o json | jq .status.loadBalancer.ingress[0].hostname
}

function get_service_hostname() {
  HOSTNAME=$(get_service)

  while [[ $HOSTNAME == null ]]; do
      HOSTNAME=$(get_service)
  done
  echo "${CHART_NAME} endpoint is: ${HOSTNAME}"
}

function progress_bar() {
  mypid=$!
  loadingText=$1
  echo -ne "$loadingText\r"
  while kill -0 $mypid 2>/dev/null; do
    echo -ne "$loadingText.\r"
    sleep 0.5
    echo -ne "$loadingText..\r"
    sleep 0.5
    echo -ne "$loadingText...\r"
    sleep 0.5
    echo -ne "\r\033[K"
    echo -ne "$loadingText\r"
    sleep 0.5
  done
}

# One way to parse YAML in Bash. A purpose-built tool would be 'yq' but it does not come installed by default so we should
# not depend on it. Python, on the other hand, comes installed by default.
function get_chart_name() {
    python3 -c "import yaml;print(yaml.safe_load(open('$1'))$2)"
}

function install_chart() {
  CHART_NAME=$(get_chart_name kubernetes/Chart.yaml "['name']")
  $HELM_BINARY_NAME upgrade --install "${CHART_NAME}" kubernetes/ --wait --timeout 300s & progress_bar "Deploying ${CHART_NAME}"
  get_service_hostname
}

validate_setup

echo "Deploying to \"$(get_kubectl_context)\" context, namespace \"$(get_kubectl_namespace)\"."
read -p "Continue? (y/n) " yn
case $yn in
    [Yy]* ) install_chart;;
    # Here I'm assuming that whoever uses this script knows how to work with kubectl, which is not always true in case
    # of an average developer. There is certainly room for improvement in this script.
    [Nn]* ) echo "If you need to deploy to a different cluster, change the context and try again.";;
    * ) echo "Please answer y or n.";;
esac

# Using Helm, we are also able to implement a rollback feature, which I won't do here due to time constraints.
