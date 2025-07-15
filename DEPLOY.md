# Gemini API Server デプロイガイド

## Railway でのデプロイ手順

### 1. 前準備
- GitHubアカウントの作成
- Railwayアカウントの作成（https://railway.app/）

### 2. GitHubリポジトリの作成
```bash
# プロジェクトディレクトリで実行
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git push -u origin main
```

### 3. Railwayでのデプロイ
1. Railway（https://railway.app/）にログイン
2. "New Project" をクリック
3. "Deploy from GitHub repo" を選択
4. 作成したリポジトリを選択
5. 自動的にビルド・デプロイが開始されます

### 4. 環境変数の設定（オプション）
- Railway のプロジェクト設定で環境変数を追加可能
- `GEMINI_API_KEY` を設定して実際のGemini APIを使用

### 5. カスタムドメインの設定（オプション）
- Railway の設定でカスタムドメインを追加可能

## 他のプラットフォーム

### Render
1. Renderアカウント作成
2. "New Web Service" を選択
3. GitHubリポジトリを接続
4. Build Command: `docker build -t app .`
5. Start Command: `docker run -p $PORT:8080 app`

### Fly.io
```bash
# Fly CLI をインストール
curl -L https://fly.io/install.sh | sh

# ログイン
fly auth login

# アプリを作成・デプロイ
fly launch
fly deploy
```

## API エンドポイント
デプロイ後、以下のエンドポイントが利用可能になります：

- `GET /health` - ヘルスチェック
- `GET /api/gemini?q=質問` - Gemini API（GET）
- `POST /api/gemini` - Gemini API（POST）
- `GET /` - API使用方法の説明

## 使用例
```bash
# デプロイされたAPIを使用
curl "https://your-app.railway.app/api/gemini?q=こんにちは"
```

## トラブルシューティング
- ビルドエラー: Dockerfileの設定を確認
- 起動エラー: ログを確認してポート設定をチェック
- API エラー: GEMINI_API_KEY の設定を確認