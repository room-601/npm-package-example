# npm-package-example

GitHub Packagesとnpmレジストリの両方に公開されているシンプルなサンプル npm パッケージです。

## 📦 インストール

このパッケージは **GitHub Packages** と **npm レジストリ**の両方にプライベートパッケージとして公開されています。

### オプション 1: npm レジストリからインストール（推奨）

npm レジストリから直接インストールできます。認証が必要です：

```bash
# npmjs.comでのログインが必要
npm login
npm install @room-601/npm-package-example
```

### オプション 2: GitHub Packages からインストール

GitHub Packages を使用する場合は、以下の設定が必要です：

#### ステップ 1: GitHub Personal Access Token (PAT) の作成

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic) に移動
2. "Generate new token (classic)" をクリック
3. 以下のスコープを選択：
   - `read:packages` - GitHub Packages からパッケージをダウンロードするために必要
4. トークンを生成してコピー

#### ステップ 2: `.npmrc` の設定

プロジェクトのルートまたはホームディレクトリ（`~/.npmrc`）に `.npmrc` を作成または更新：

```text
@room-601:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_PAT_HERE
```

**⚠️ 重要**: トークンを含む `.npmrc` を Git にコミットしないでください。`.gitignore` に追加してください。

#### ステップ 3: パッケージのインストール

```bash
npm install @room-601/npm-package-example
```

## 🔧 使い方

```typescript
import { greet } from '@room-601/npm-package-example';

console.log(greet('World')); // Hello, World!
```

## 🚀 公開方法（メンテナー向け）

このパッケージは、バージョン管理と自動公開に [Changesets](https://github.com/changesets/changesets) を使用しています。1回の公開で **GitHub Packages** と **npm レジストリ**の両方に自動的に公開されます。

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
  - PR がマージされると、自動的に **GitHub Packages** と **npm レジストリ**の両方に公開

- **Pre-release ワークフロー**: プレリリースバージョンのテスト用
  - プレリリースモードに入る：プレリリースバージョンを作成（例：`1.0.4-next.0`）
  - プレリリースモードを終了：通常のバージョニングに戻る

**公開フロー**:
1. GitHub Packagesに公開（1回目）
2. `postpublish`スクリプトが自動実行
3. npmレジストリに公開（2回目）

### GitHub Actions の設定

#### 必要な権限

ワークフローには、GitHub Actions で以下の権限が必要です：

```yaml
permissions:
  contents: write    # コミットとタグの作成用
  packages: write    # GitHub Packages への公開用
  pull-requests: write # バージョン PR の作成用
```

#### 必要なシークレット

**1. GITHUB_TOKEN（自動提供）**
- GitHub Actions によって自動的に提供
- GitHub Packages への公開に使用

**2. NPM_TOKEN（要手動設定）**
- npm レジストリへの公開に必要
- 以下の手順で設定してください：

##### NPM_TOKEN の作成手順

1. [npmjs.com](https://www.npmjs.com/)にログイン
2. Account Settings → Access Tokens → Generate New Token
3. **Granular Access Token**を選択
4. 設定内容：
   - **Token name**: `GitHub Actions CI` (任意の名前)
   - **Expiration**: 90 days（最大）
   - **Packages and scopes**: `@room-601/npm-package-example`を選択
   - **Permissions**: Read and Write
   - **Bypass 2FA**: 有効化（CI/CD実行に必要）
5. トークンを生成してコピー

##### GitHubリポジトリにシークレットを追加

1. GitHubリポジトリページにアクセス
2. Settings → Secrets and variables → Actions
3. **New repository secret**をクリック
4. 以下を入力：
   - **Name**: `NPM_TOKEN`
   - **Secret**: コピーしたトークンを貼り付け
5. **Add secret**をクリック

**⚠️ 重要**: Granular Access Tokenは最大90日で期限切れになります。期限が切れる前に新しいトークンを生成して更新してください。

## 📋 パッケージ設定

### `package.json` の設定

両方のレジストリに公開するための重要な設定：

```json
{
  "name": "@room-601/npm-package-example",
  "publishConfig": {
    "@room-601:registry": "https://npm.pkg.github.com",
    "access": "restricted"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/room-601/npm-package-example.git"
  },
  "scripts": {
    "postpublish": "npm run publish-npm",
    "publish-npm": "npm publish --access restricted --ignore-scripts --@room-601:registry='https://registry.npmjs.org'"
  }
}
```

**重要な注意事項：**
- パッケージ名はスコープ付きである必要があります（`@room-601/...`）
- `@room-601:registry`：スコープ付きレジストリ設定（changesets 2.30.0+でサポート）
- `access: "restricted"` でプライベートパッケージになります
- `postpublish`スクリプト：GitHub Packages公開後、自動的にnpmレジストリにも公開
- `--ignore-scripts`：無限ループ防止のため、2回目の公開時はスクリプトを実行しない

### `.npmrc` の設定

ローカル開発およびリポジトリ内での設定：

```text
@room-601:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN}
```

- `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` 環境変数を使用
- GitHub Actions では `actions/setup-node` が自動的にこれを提供

## 🔄 デュアルレジストリ公開の仕組み

このパッケージは **postpublish** ライフサイクルスクリプトを使用して、1回の公開コマンドで両方のレジストリに自動公開します。

### 公開フロー

```
npm run ci:publish（changesets publish）
    ↓
【1回目】GitHub Packagesに公開
    ↓
成功すると postpublish スクリプトが自動実行
    ↓
【2回目】npmレジストリに公開（--ignore-scripts で無限ループ防止）
    ↓
✅ 両方のレジストリで利用可能
```

### 各レジストリの特徴

**GitHub Packages:**
- GitHub組織のアクセス制御と統合
- `GITHUB_TOKEN`で認証（追加設定不要）
- リポジトリと同じ権限管理

**npm レジストリ:**
- 広く使われている標準的なレジストリ
- `NPM_TOKEN`（Granular Access Token）で認証
- npmjs.comのアカウントでアクセス管理  

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
- `npm run publish-npm` - npmレジストリへの公開（postpublishから自動実行）

## 📝 ライセンス

MIT © KosukeTakahashi0410

## 🔗 リンク

- [GitHub リポジトリ](https://github.com/room-601/npm-package-example)
- [GitHub Packages](https://github.com/room-601/npm-package-example/packages)
- [Changesets ドキュメント](https://github.com/changesets/changesets)

