#!/usr/bin/env bash

# This script uses arg $1 (name of *.jsonnet file to use) to generate the manifests/*.yaml files.

set -e
set -x
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

# Make sure to start with a clean 'manifests' dir
rm -rf manifests
mkdir -p manifests/setup

                                               # optional, but we would like to generate yaml, not json
jsonnet -J vendor -m manifests "${1-example.jsonnet}" | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml; rm -f {}' -- {}

echo "Patching manifests to add node selector"

CRD_FILES="
alertmanager-alertmanager.yaml
prometheus-prometheus.yaml
"

for F in $CRD_FILES; do
    kubectl patch --local=true -f manifests/"${F}" -p '{"spec": {"nodeSelector": {"kops.k8s.io/instancegroup": "tools"}}}' -o yaml --type merge > manifests/"${F}".new && mv manifests/"${F}".new manifests/"${F}"
done

DEPLOYMENT_FILES="
grafana-deployment.yaml
0prometheus-operator-deployment.yaml
kube-state-metrics-deployment.yaml
prometheus-adapter-deployment.yaml
"

for F in $DEPLOYMENT_FILES; do
    kubectl patch --local=true -f manifests/"${F}" -p '{"spec": {"template": {"spec": {"nodeSelector": {"kops.k8s.io/instancegroup": "tools"}}}}}' -o yaml --type merge > manifests/"${F}".new && mv manifests/"${F}".new manifests/"${F}"
done