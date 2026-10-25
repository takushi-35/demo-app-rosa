#!/usr/bin/env bash
# パイプラインを手動で実行します
set -euo pipefail

: "${GIT_REPO_URL:?GIT_REPO_URL を設定してください}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

sed "s#GIT_REPO_URL#${GIT_REPO_URL}#" "$ROOT/pipeline/pipelinerun.yaml" \
  | oc -n cicd-demo create -f -
echo "進捗確認: oc -n cicd-demo get pipelinerun -w  (または tkn pipelinerun logs -f -L -n cicd-demo)"
