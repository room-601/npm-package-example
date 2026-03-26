#!/bin/bash
set -e

# このスクリプトは postpublish フックから呼ばれ、
# GitHub Packages へのpublish後に、npmjs へ異なるスコープでpublishします

PACKAGE_JSON="package.json"
BACKUP_PACKAGE_JSON="package.json.backup"
TEMP_PACKAGE_JSON="package.json.npm-publish"

# 安全性のため：既存の一時ファイルをクリーンアップ
if [ -f "$TEMP_PACKAGE_JSON" ]; then
  echo "Cleaning up existing temporary file: $TEMP_PACKAGE_JSON"
  rm "$TEMP_PACKAGE_JSON"
fi
if [ -f "$BACKUP_PACKAGE_JSON" ]; then
  echo "Cleaning up existing backup file: $BACKUP_PACKAGE_JSON"
  rm "$BACKUP_PACKAGE_JSON"
fi

# エラー発生時にも一時ファイルを確実に削除・復元
trap 'rm -f "$TEMP_PACKAGE_JSON"; if [ -f "$BACKUP_PACKAGE_JSON" ]; then mv -f "$BACKUP_PACKAGE_JSON" "$PACKAGE_JSON"; fi' EXIT

# 現在のパッケージ名を取得（例: @room-601/add）
CURRENT_NAME=$(node -p "require('./package.json').name")
# パッケージ名の後半部分を取得（例: add）
PACKAGE_BASE_NAME=$(echo "$CURRENT_NAME" | sed 's/.*\///')

# npmjs用のパッケージ名（例: @kosuketakahashi0410/add）
NPM_PACKAGE_NAME="@kosuketakahashi0410/$PACKAGE_BASE_NAME"

echo "================================================"
echo "Publishing to npmjs"
echo "Original name: $CURRENT_NAME"
echo "New name for npmjs: $NPM_PACKAGE_NAME"
echo "Registry: https://registry.npmjs.org/"
echo "================================================"

# package.jsonを一時コピーして、パッケージ名を変更
cp "$PACKAGE_JSON" "$TEMP_PACKAGE_JSON"
node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('$TEMP_PACKAGE_JSON', 'utf8'));
  pkg.name = '$NPM_PACKAGE_NAME';
  // npmjs用の設定に変更（publishConfigを明示的に上書き）
  pkg.publishConfig = {
    registry: 'https://registry.npmjs.org/',
    access: 'public'
  };
  fs.writeFileSync('$TEMP_PACKAGE_JSON', JSON.stringify(pkg, null, 2));
"

# 元のpackage.jsonをバックアップ
cp "$PACKAGE_JSON" "$BACKUP_PACKAGE_JSON"

# 変更したpackage.jsonで上書き
cp "$TEMP_PACKAGE_JSON" "$PACKAGE_JSON"

# npmjsにpublish（現在のディレクトリのpackage.jsonが変更済み）
# 環境変数で明示的にレジストリを設定し、.npmrcの影響を回避
NPM_CONFIG_REGISTRY=https://registry.npmjs.org/ \
NPM_CONFIG_@room-601:registry= \
npm publish \
  --registry https://registry.npmjs.org/ \
  --ignore-scripts \
  --access public

# 元のpackage.jsonを復元
mv "$BACKUP_PACKAGE_JSON" "$PACKAGE_JSON"

echo "✓ Successfully published to npmjs as: $NPM_PACKAGE_NAME"
