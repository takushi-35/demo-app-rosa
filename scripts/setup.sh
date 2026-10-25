#!/usr/bin/env bash
# デモ環境 (Namespace / Pipeline / Trigger / Argo CD Application) を構築します
#
# 必要な環境変数:
#   GIT_REPO_URL  例: https://github.com/your-org/demo-app.git
#   GIT_USERNAME  GitHub ユーザー名
#   GIT_TOKEN     リポジトリへの push 権限を持つ Personal Access Token
set -euo pipefail

: "${GIT_REPO_URL:?GIT_REPO_URL を設定してください}"
: "${GIT_USERNAME:?GIT_USERNAME を設定してください}"
: "${GIT_TOKEN:?GIT_TOKEN を設定してください}"

NS=cicd-demo
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Namespace (Argo CD が管理できるようにラベルを付与)
oc create namespace "$NS" --dry-run=client -o yaml | oc apply -f -
oc label namespace "$NS" argocd.argoproj.io/managed-by=openshift-gitops --overwrite

# Secret
oc -n "$NS" create secret generic git-credentials \
  --from-literal=username="$GIT_USERNAME" \
  --from-literal=token="$GIT_TOKEN" \
  --dry-run=client -o yaml | oc apply -f -

if ! oc -n "$NS" get secret github-webhook-secret >/dev/null 2>&1; then
  oc -n "$NS" create secret generic github-webhook-secret \
    --from-literal=secretToken="$(openssl rand -hex 20)"
fi

# Tekton
oc -n "$NS" apply -f "$ROOT/pipeline/tasks/"
oc -n "$NS" apply -f "$ROOT/pipeline/pipeline.yaml"
oc -n "$NS" apply -f "$ROOT/pipeline/triggers/"

# Argo CD
sed "s#GIT_REPO_URL#${GIT_REPO_URL}#" "$ROOT/argocd/application.yaml" | oc apply -f -

WEBHOOK_URL="https://$(oc -n "$NS" get route el-github-listener -o jsonpath='{.spec.host}')"
WEBHOOK_SECRET="$(oc -n "$NS" get secret github-webhook-secret -o jsonpath='{.data.secretToken}' | base64 -d)"

cat <<MSG

==== セットアップ完了 ====
GitHub リポジトリの Settings > Webhooks で以下を登録してください:
  Payload URL : ${WEBHOOK_URL}
  Content type: application/json
  Secret      : ${WEBHOOK_SECRET}
  Events      : Just the push event

初回は手動でパイプラインを実行してください:
  GIT_REPO_URL=${GIT_REPO_URL} ./scripts/run-pipeline.sh
MSG
