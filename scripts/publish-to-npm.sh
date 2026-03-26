#!/bin/bash
set -e

# このスクリプトは postpublish フックから呼ばれ、
# GitHub Packages へのpublish後に、npmjs へ異なるスコープでpublishします

PACKAGE_JSON="package.json"
BACKUP_PACKAGE_JSON="package.json.backup"
NPMRC_FILE=".npmrc"
BACKUP_NPMRC_FILE=".npmrc.backup"

# 安全性のため：既存のバックアップファイルをクリーンアップ
if [ -f "$BACKUP_PACKAGE_JSON" ]; then
  echo "Cleaning up existing backup file: $BACKUP_PACKAGE_JSON"
  rm "$BACKUP_PACKAGE_JSON"
fi
if [ -f "$BACKUP_NPMRC_FILE" ]; then
  echo "Cleaning up existing backup file: $BACKUP_NPMRC_FILE"
  rm "$BACKUP_NPMRC_FILE"
fi

# エラー発生時にも確実に復元
trap 'if [ -f "$BACKUP_PACKAGE_JSON" ]; then mv -f "$BACKUP_PACKAGE_JSON" "$PACKAGE_JSON"; fi; if [ -f "$BACKUP_NPMRC_FILE" ]; then mv -f "$BACKUP_NPMRC_FILE" "$NPMRC_FILE"; fi' EXIT

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

# 元のpackage.jsonをバックアップ
cp "$PACKAGE_JSON" "$BACKUP_PACKAGE_JSON"

# package.jsonを直接変更
node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('$PACKAGE_JSON', 'utf8'));
  pkg.name = '$NPM_PACKAGE_NAME';
  // npmjs用の設定に変更（publishConfigを明示的に上書き）
  pkg.publishConfig = {
    registry: 'https://registry.npmjs.org/',
    access: 'public'
  };
  fs.writeFileSync('$PACKAGE_JSON', JSON.stringify(pkg, null, 2));
"

# .npmrcファイルが存在する場合はバックアップして削除
# （GitHub Packagesへの設定を一時的に無効化）
if [ -f "$NPMRC_FILE" ]; then
  cp "$NPMRC_FILE" "$BACKUP_NPMRC_FILE"
  rm "$NPMRC_FILE"
fi

# npmjsにpublish（package.jsonとpublishConfigが変更済み、.npmrcも削除済み）
npm publish --ignore-scripts

# 元のファイルを復元
mv "$BACKUP_PACKAGE_JSON" "$PACKAGE_JSON"
if [ -f "$BACKUP_NPMRC_FILE" ]; then
  mv "$BACKUP_NPMRC_FILE" "$NPMRC_FILE"
fi

echo "✓ Successfully published to npmjs as: $NPM_PACKAGE_NAME"
