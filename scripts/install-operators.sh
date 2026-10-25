#!/usr/bin/env bash
# OpenShift Pipelines / OpenShift GitOps オペレーターをインストールします (要 cluster-admin)
set -euo pipefail

oc apply -f - <<'YAML'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator-rh
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-gitops-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-gitops-operator
  namespace: openshift-gitops-operator
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-gitops-operator
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
YAML

echo "オペレーターの起動を待っています..."
until oc get crd pipelines.tekton.dev applications.argoproj.io >/dev/null 2>&1; do sleep 10; done
until oc get ns openshift-gitops >/dev/null 2>&1; do sleep 10; done
oc wait --for=condition=Available deployment --all -n openshift-gitops --timeout=600s
echo "完了しました"
