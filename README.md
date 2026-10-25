# ROSA CI/CD デモ

ROSA (Red Hat OpenShift Service on AWS) 上で **OpenShift Pipelines (Tekton)** による CI と
**OpenShift GitOps (Argo CD)** による CD を組み合わせたデモです。

```
 git push ──▶ GitHub ──webhook──▶ EventListener (Tekton Triggers)
                                        │
                                        ▼
            ┌──────────── demo-app-pipeline ────────────┐
            │ fetch-source → run-tests → build-image →   │
            │                           update-manifest  │
            └────────────────────────────────┬──────────┘
                    │ push イメージ             │ k8s/kustomization.yaml の
                    ▼                          │ newTag を書き換えて git push
          OpenShift 内部レジストリ               ▼
                    ▲                       GitHub (k8s/)
                    │ pull                     │ 検知・同期
                    └──── Deployment ◀──── Argo CD
```

## 構成

| パス | 内容 |
|---|---|
| `app/` | Flask アプリ (`/`, `/api/info`, `/healthz`) とテスト |
| `Containerfile` | UBI9 Python 3.12 ベースのコンテナイメージ |
| `k8s/` | Deployment / Service / Route (kustomize)。Argo CD が同期 |
| `pipeline/` | Tekton の Task / Pipeline / Trigger |
| `argocd/` | Argo CD Application |
| `scripts/` | オペレーター導入・セットアップ・手動実行スクリプト |

## 前提

- ROSA クラスタと `oc` CLI (cluster-admin でログイン済み)
- GitHub リポジトリ (このディレクトリを push しておく)
- そのリポジトリへの push 権限を持つ GitHub Personal Access Token
  (Fine-grained なら対象リポジトリの *Contents: Read and write*)
- OpenShift Pipelines 1.17 以降 (`openshift-pipelines` namespace の `git-clone` / `buildah` タスクを cluster resolver で使用)

## 手順

### 1. リポジトリを GitHub に push

```bash
git init -b main
git add . && git commit -m "initial commit"
git remote add origin https://github.com/<your-org>/demo-app.git
git push -u origin main
```

### 2. オペレーターのインストール (未導入の場合)

```bash
./scripts/install-operators.sh
```

### 3. デモ環境のセットアップ

```bash
export GIT_REPO_URL=https://github.com/<your-org>/demo-app.git
export GIT_USERNAME=<github-user>
export GIT_TOKEN=<personal-access-token>
./scripts/setup.sh
```

最後に表示される Payload URL / Secret を GitHub の **Settings > Webhooks** に登録します。

### 4. 初回パイプライン実行

初期状態ではイメージが存在しないため、Pod は `ImagePullBackOff` になります。
一度パイプラインを実行してイメージを作成してください。

```bash
./scripts/run-pipeline.sh
tkn pipelinerun logs -f -L -n cicd-demo   # tkn がある場合
```

完了するとマニフェスト更新コミットが push され、Argo CD がデプロイします。

```bash
oc -n cicd-demo get route demo-app -o jsonpath='https://{.spec.host}{"\n"}'
```

## デモシナリオ

1. ブラウザでアプリを開く (赤背景 / Version: v1)
2. `app/app.py` の `VERSION = "v2"` に変更、または `k8s/deployment.yaml` の `APP_COLOR` を `#0066cc` などに変更
3. `git commit -am "v2" && git push`
4. OpenShift コンソールの **Pipelines** でパイプラインの進行を確認
5. **Argo CD** (`oc get route openshift-gitops-server -n openshift-gitops`) で同期を確認
6. ブラウザをリロードして新バージョンが表示されることを確認

おまけ: テストを壊して push すると `run-tests` で止まり、デプロイされないことも見せられます。

## 補足

- Pipeline が push するコミットには `[skip ci]` が付き、EventListener の CEL フィルタで無視されるため無限ループしません。
- `k8s/` のみの変更 (例: `APP_COLOR` の変更) でもパイプラインが走ります。
  Argo CD だけで反映させたい場合は、コミットメッセージに `[skip ci]` を付けてください。
- Argo CD の UI ログインは OpenShift アカウントで行えます。

## 片付け

```bash
oc delete application demo-app -n openshift-gitops
oc delete clusterrolebinding cicd-demo-tekton-triggers-eventlistener-clusterbinding
oc delete namespace cicd-demo
```
