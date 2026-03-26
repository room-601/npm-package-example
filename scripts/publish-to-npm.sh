#!/bin/bash
set -e

# このスクリプトは postpublish フックから呼ばれ、
# GitHub Packages へのpublish後に、npmjs へ異なるスコープでpublishします

PACKAGE_JSON="package.json"
TEMP_PACKAGE_JSON="package.json.npm-publish"

# 安全性のため：既存の一時ファイルをクリーンアップ
if [ -f "$TEMP_PACKAGE_JSON" ]; then
  echo "Cleaning up existing temporary file: $TEMP_PACKAGE_JSON"
  rm "$TEMP_PACKAGE_JSON"
fi

# エラー発生時にも一時ファイルを確実に削除
trap 'rm -f "$TEMP_PACKAGE_JSON"' EXIT

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

# 一時的なpackage.jsonでnpmjsにpublish
# --registry フラグで明示的にnpmjsのみを指定
# --userconfig /dev/null で .npmrc の設定を無視
npm publish "$TEMP_PACKAGE_JSON" \
  --registry https://registry.npmjs.org/ \
  --ignore-scripts \
  --access public \
  --userconfig /dev/null

echo "✓ Successfully published to npmjs as: $NPM_PACKAGE_NAME"
