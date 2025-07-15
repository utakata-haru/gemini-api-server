#!/bin/bash

# Gemini API Server デプロイスクリプト

echo "🚀 Gemini API Server デプロイ準備"

# Gitリポジトリの初期化（まだの場合）
if [ ! -d ".git" ]; then
    echo "📁 Gitリポジトリを初期化中..."
    git init
    git branch -M main
fi

# ファイルをステージング
echo "📝 ファイルをステージング中..."
git add .

# コミット
echo "💾 変更をコミット中..."
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"

echo "✅ デプロイ準備完了！"
echo ""
echo "次のステップ:"
echo "1. GitHubでリポジトリを作成"
echo "2. リモートリポジトリを追加:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git"
echo "3. プッシュ:"
echo "   git push -u origin main"
echo ""
echo "デプロイプラットフォーム:"
echo "🚂 Railway: https://railway.app/"
echo "🎨 Render: https://render.com/"
echo "🪰 Fly.io: https://fly.io/"
echo ""
echo "詳細な手順は DEPLOY.md を参照してください。"