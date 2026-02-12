# npm-package-example

GitHub Packages プライベートレジストリに公開されているシンプルなサンプル npm パッケージです。

## 📦 インストール

このパッケージは GitHub Packages にプライベートパッケージとして公開されています。インストールするには、`@room-601` スコープに対して GitHub Packages レジストリを使用するように npm を設定する必要があります。

### ステップ 1: GitHub Personal Access Token (PAT) の作成

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic) に移動
2. "Generate new token (classic)" をクリック
3. 以下のスコープを選択：
   - `read:packages` - GitHub Packages からパッケージをダウンロードするために必要
   - `write:packages` - パッケージを公開する必要がある場合に必要（利用者には不要）
4. トークンを生成してコピー

### ステップ 2: `.npmrc` の設定

プロジェクトのルートまたはホームディレクトリ（`~/.npmrc`）に `.npmrc` を作成または更新：

```text
@room-601:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_PAT_HERE
```

**⚠️ 重要**: トークンを含む `.npmrc` を Git にコミットしないでください。`.gitignore` に追加してください。

### ステップ 3: パッケージのインストール

```bash
npm install @room-601/npm-package-example
```

## 🔧 使い方

```typescript
import { greet } from '@room-601/npm-package-example';

console.log(greet('World')); // Hello, World!
```

## 🚀 公開方法（メンテナー向け）

このパッケージは、バージョン管理と GitHub Packages への自動公開に [Changesets](https://github.com/changesets/changesets) を使用しています。

### 公開ワークフロー

#### 1. changeset の作成

変更を加えたら、その内容を説明する changeset を作成します：

```bash
npx changeset
```

プロンプトに従って以下を入力：
- 変更の種類を選択（major, minor, patch）
- 変更の要約を入力

これにより、`.changeset/` ディレクトリにマークダウンファイルが作成されます。

#### 2. コミットとプッシュ

```bash
git add .
git commit -m "feat: 機能の説明"
git push
```

#### 3. 自動リリースプロセス

パッケージは GitHub Actions を通じて自動的に公開されます：

- **Release ワークフロー**: `main` ブランチへのプッシュでトリガー
  - バージョンアップを含む "Version Packages" PR を作成
  - PR がマージされると、自動的に GitHub Packages に公開

- **Pre-release ワークフロー**: プレリリースバージョンのテスト用
  - プレリリースモードに入る：プレリリースバージョンを作成（例：`1.0.4-next.0`）
  - プレリリースモードを終了：通常のバージョニングに戻る

### GitHub Actions の設定

#### 必要な権限

ワークフローには、GitHub Actions で以下の権限が必要です：

```yaml
permissions:
  contents: write    # コミットとタグの作成用
  packages: write    # GitHub Packages への公開用
  pull-requests: write # バージョン PR の作成用
```

#### 認証

- **`GITHUB_TOKEN`**: GitHub Actions によって自動的に提供
- **`NODE_AUTH_TOKEN`**: GitHub Packages での認証のために `GITHUB_TOKEN` に設定

追加のシークレット設定は不要です！🎉

## 📋 パッケージ設定

### `package.json` の設定

GitHub Packages 用の重要な設定：

```json
{
  "name": "@room-601/npm-package-example",
  "publishConfig": {
    "registry": "https://npm.pkg.github.com",
    "access": "restricted"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/room-601/npm-package-example.git"
  }
}
```

**重要な注意事項：**
- パッケージ名はスコープ付きである必要があります（`@room-601/...`）
- スコープは GitHub の organization/username と一致する必要があります
- `access: "restricted"` でプライベートパッケージになります
- `registry` は GitHub Packages を指定

### `.npmrc` の設定

ローカル開発およびリポジトリ内での設定：

```text
@room-601:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}
```

- `NODE_AUTH_TOKEN` 環境変数を使用
- GitHub Actions では `actions/setup-node` が自動的にこれを提供

## 🔄 npm レジストリからの移行

このパッケージは以前、パブリック npm レジストリに公開されていましたが、GitHub Packages プライベートレジストリに移行されました。

### 主な変更点

#### 1. レジストリ URL
- **移行前**: `https://registry.npmjs.org`
- **移行後**: `https://npm.pkg.github.com`

#### 2. 認証方式
- **移行前**: OIDC を使用した npm Trusted Publishing（トークンレス）
- **移行後**: GitHub Token 認証（`NODE_AUTH_TOKEN`）

#### 3. アクセス制御
- **移行前**: `"access": "public"`
- **移行後**: `"access": "restricted"`

#### 4. GitHub Actions の権限
- **移行前**: `id-token: write`（OIDC 用）
- **移行後**: `packages: write`（GitHub Packages 用）

#### 5. 環境変数
- **移行前**: 追加の環境変数不要（OIDC）
- **移行後**: `NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}`

### GitHub Packages のメリット

✅ **デフォルトでプライベート** - 内部パッケージのセキュリティ向上  
✅ **GitHub と統合** - 同じ認証と権限管理  
✅ **追加トークン不要** - Actions で `GITHUB_TOKEN` を使用  
✅ **きめ細かいアクセス制御** - GitHub リポジトリの権限で管理  

## 🛠️ 開発

### 前提条件

- Node.js 20.15.1 以上
- npm 10.x 以上

### セットアップ

```bash
# 依存関係のインストール
npm install

# パッケージのビルド
npm run build
```

### スクリプト

- `npm run build` - TypeScript を JavaScript にコンパイル
- `npm run ci:version` - パッケージのバージョン管理（CI で使用）
- `npm run ci:publish` - パッケージの公開（CI で使用）

## 📝 ライセンス

MIT © KosukeTakahashi0410

## 🔗 リンク

- [GitHub リポジトリ](https://github.com/room-601/npm-package-example)
- [GitHub Packages](https://github.com/room-601/npm-package-example/packages)
- [Changesets ドキュメント](https://github.com/changesets/changesets)

