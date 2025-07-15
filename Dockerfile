# マルチステージビルドでDartアプリケーションをコンパイル
FROM ghcr.io/cirruslabs/flutter:stable AS build

# 作業ディレクトリを設定
WORKDIR /app

# pubspec.yamlとpubspec.lockをコピーして依存関係を解決
COPY pubspec.* ./
RUN flutter pub get

# ソースコードをコピー
COPY . .

# サーバーアプリケーションを実行可能ファイルにコンパイル
RUN dart compile exe lib/server.dart -o server

# 本番用の軽量イメージ
FROM debian:bullseye-slim

# 必要なランタイムライブラリをインストール
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを作成
WORKDIR /app

# ビルドステージからコンパイル済みの実行ファイルをコピー
COPY --from=build /app/server /app/server

# ポート8080を公開
EXPOSE 8080

# サーバーを起動
CMD ["/app/server"]