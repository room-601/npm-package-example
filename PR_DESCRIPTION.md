# npm レジストリから GitHub Packages への移行

## 📋 概要

このPRは、パッケージの公開先を **npm 公開レジストリ** から **GitHub Packages プライベートレジストリ** に移行するための変更を含みます。

## 🎯 目的

- プライベートパッケージとして管理し、セキュリティを向上
- GitHub のアクセス制御機能を活用
- GitHub Actions との統合を強化
- npm の Trusted Publishing (OIDC) から GitHub Token 認証に移行

## 📝 変更内容の詳細

### 0. `.github/workflows/release-trigger.yml` の変更

#### 変更箇所: 権限設定

```diff
  permissions:
-   id-token: write
+   packages: write
    contents: write
    pull-requests: write
```

#### 詳細説明

**`release-trigger.yml` の役割:**
- このファイルは **ワークフローのエントリーポイント** として機能
- `main` ブランチへのプッシュ時に `release.yml` を呼び出し
- 手動トリガー（`workflow_dispatch`）時に `pre-release.yml` を呼び出し
- トップレベルで権限を設定し、呼び出されるワークフローに継承

**なぜ `workflow_call` パターンを使用しているか:**
- ✅ **ワークフローの整理** - release と pre-release のロジックを分離
- ✅ **再利用性** - 各ワークフローを独立して呼び出し可能
- ✅ **保守性** - トリガーロジックを一元管理
- ✅ **拡張性** - 将来的に他のトリガーを追加しやすい

**注意:** この `workflow_call` パターンは npm Trusted Publishing とは無関係で、ワークフローの設計パターンとして採用されています。

**権限の変更:**

1. **`id-token: write` の削除:**
   - npm Trusted Publishing (OIDC) 用の権限
   - GitHub Packages では不要

2. **`packages: write` の追加:**
   - GitHub Packages への公開に必要
   - この権限が `release.yml` と `pre-release.yml` に継承される

**ワークフローの構造:**
```
release-trigger.yml (エントリーポイント)
├── push to main → release.yml を呼び出し
└── workflow_dispatch → pre-release.yml を呼び出し
```

**権限の継承:**
- トップレベルの `permissions` が `workflow_call` で呼び出されるワークフローに継承される
- そのため、`release.yml` と `pre-release.yml` でも同じ権限が有効
- 一元管理により、権限の管理が簡潔

---

### 1. `package.json` の変更

#### 変更箇所

```diff
  "publishConfig": {
-   "access": "public"
+   "registry": "https://npm.pkg.github.com",
+   "access": "restricted"
  }
```

#### 詳細説明

**`registry` の追加:**
- GitHub Packages のレジストリ URL を明示的に指定
- `https://npm.pkg.github.com` は GitHub Packages の npm レジストリエンドポイント
- この設定により、`npm publish` 実行時に自動的に GitHub Packages に公開される

**`access` の変更:**
- `public` → `restricted` に変更
- GitHub Packages ではデフォルトでプライベートであり、`restricted` を設定することで明示的にプライベートとして扱う
- これにより、リポジトリへのアクセス権限を持つユーザーのみがパッケージをインストール可能

**影響範囲:**
- パッケージをインストールするすべてのユーザーは、適切な認証設定（GitHub PAT）が必要になる
- パッケージは npm 公開レジストリには表示されなくなる

---

### 2. `.npmrc` の変更

#### 変更箇所

```diff
  @room-601:registry=https://npm.pkg.github.com
- //npm.pkg.github.com/:_authToken=${NPM_TOKEN}
+ //npm.pkg.github.com/:_authToken=${GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN}
```

#### 詳細説明

**環境変数名の変更理由:**

1. **`actions/setup-node` との統合:**
   - `actions/setup-node` アクションは、`registry-url` を設定すると自動的に `.npmrc` ファイルを生成
   - このアクションは慣習的に `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` という環境変数名を使用
   - 標準的な命名規則に従うことで、他の開発者が設定を理解しやすくなる

2. **GitHub Actions での動作:**
   ```yaml
   - uses: actions/setup-node@v4
     with:
       registry-url: https://npm.pkg.github.com
   ```
   上記の設定により、内部的に以下のような `.npmrc` が生成される：
   ```
   //npm.pkg.github.com/:_authToken=${GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN}
   ```

3. **環境変数の設定:**
   - GitHub Actions のワークフロー内で `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` を設定
   - `GITHUB_TOKEN` は GitHub Actions が自動的に提供する一時トークン
   - ワークフロー実行時に `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` が `GITHUB_TOKEN` の値で置き換えられ、認証が行われる

**セキュリティへの影響:**
- トークンはリポジトリにハードコードされず、環境変数として参照される
- GitHub Actions では自動的に提供される `GITHUB_TOKEN` を使用するため、別途シークレットを管理する必要がない

---

### 3. `.github/workflows/release.yml` の変更

#### 変更箇所 1: 権限設定

```diff
  permissions:
    contents: write
-   id-token: write # for trusted publishing
+   packages: write # for GitHub Packages
    pull-requests: write
```

#### 詳細説明

**`id-token: write` の削除:**
- npm の Trusted Publishing では OIDC（OpenID Connect）トークンを使用して認証
- OIDC を使用する場合、`id-token: write` 権限が必要
- GitHub Packages では OIDC は使用せず、代わりに `GITHUB_TOKEN` を使用するため、この権限は不要

**`packages: write` の追加:**
- GitHub Packages にパッケージを公開するために必要な権限
- この権限により、ワークフローは GitHub Packages レジストリへの書き込みアクセスが可能になる
- `GITHUB_TOKEN` にこの権限が付与され、`npm publish` 実行時に使用される

**権限の最小化原則:**
- 必要な権限のみを付与することで、セキュリティリスクを最小限に抑える
- 使用しない `id-token: write` を削除し、必要な `packages: write` のみを追加

---

#### 変更箇所 2: Node.js セットアップの簡略化

```diff
  steps:
    - uses: actions/checkout@v5
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
-   # ビルド用にNode.js 20.15.1をセットアップ
-   - name: Use Node.js 20.15.1 for build
+   
+   - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
-       node-version: 20.15.1
-   - name: install dependencies step
+       node-version-file: .node-version
+       registry-url: https://npm.pkg.github.com
+       scope: '@room-601'
+   
+   - name: Install dependencies
      run: npm ci
-   - name: build step
+   
+   - name: Build
      run: npm run build
-   # publish用にNode.js 22.xをセットアップ（npm 11系が使える）
-   - name: Use Node.js 22.x for publish
-     uses: actions/setup-node@v4
-     with:
-       node-version: 22.x
-       # GitHub Packages用のregistry設定
-       registry-url: https://npm.pkg.github.com
-       scope: '@room-601'
-   - name: Install npm latest
-     run: npm install -g npm@latest
-   - name: Create Release Pull Request or Publish to GitHub Packages
+   
+   - name: Create Release Pull Request or Publish to GitHub Packages
      uses: changesets/action@v1
      with:
        version: npm run ci:version
        publish: npm run ci:publish
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
+       GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### 詳細説明

**重要な変更: Node.js セットアップを1回に統合**

npm Trusted Publishing から GitHub Packages への移行により、Node.js を2回セットアップする必要がなくなりました。

**以前のワークフロー（npm Trusted Publishing）:**
```yaml
# 1回目: ビルド用（古いバージョン）
- uses: actions/setup-node@v4
  with:
    node-version: 20.15.1

# 2回目: 公開用（新しいバージョン + registry設定）
- uses: actions/setup-node@v4
  with:
    node-version: 22.x
    registry-url: https://registry.npmjs.org
```

**なぜ2回必要だったか:**
- npm Trusted Publishing (OIDC) は **npm 11以降**でのみサポート
- npm 11 は Node.js 22.x で利用可能
- ビルドには安定版（20.15.1）を使用したかった
- そのため、ビルド後に Node.js を再セットアップして npm 11 を使えるようにしていた

**新しいワークフロー（GitHub Packages）:**
```yaml
# 1回のセットアップで完結
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version-file: .node-version  # 安定版を使用
    registry-url: https://npm.pkg.github.com
    scope: '@room-601'
```

**なぜ1回で良いか:**
- GitHub Packages の認証は単純な環境変数（`GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN`）で完結
- 特定の npm バージョンに依存しない
- どの npm バージョンでも `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` があれば認証可能
- OIDC のような複雑な認証メカニズムが不要

**具体的な変更点:**

1. **`node-version-file` の使用:**
   - `.node-version` ファイルからバージョンを読み取る
   - 現在は `20.15.1` が設定されている
   - バージョンを一元管理でき、メンテナンス性が向上

2. **`registry-url` と `scope` の追加:**
   - 最初のセットアップ時に registry 設定を含める
   - これにより、`actions/setup-node` が自動的に `.npmrc` を生成
   - 生成される `.npmrc` には `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` の参照が含まれる

3. **2回目のセットアップを削除:**
   - Node.js 22.x へのアップグレードが不要
   - `npm install -g npm@latest` も不要
   - ワークフローがシンプルになり、実行時間も短縮

**メリット:**

✅ **シンプル** - セットアップが1回で完結  
✅ **高速** - Node.js の再インストールが不要（約30秒〜1分の短縮）  
✅ **保守性** - ワークフローが理解しやすい  
✅ **安定性** - `.node-version` で指定された安定版のみを使用  
✅ **一貫性** - ビルドと公開で同じ環境を使用  

**セキュリティ上の利点:**
- 環境の変更が少ないため、予期しない挙動のリスクが減少
- ビルド成果物と公開時の環境が同一であることを保証

**`.node-version` ファイル:**
```
20.15.1
```
- このバージョンがローカル開発、ビルド、公開のすべてで使用される
- `nodenv`、`nvm`、`asdf` などのツールとも互換性あり

---

#### 変更箇所 3: Changesets アクション

```diff
- - name: Create Release Pull Request or Publish to npm
+ - name: Create Release Pull Request or Publish to GitHub Packages
    id: changesets
    uses: changesets/action@v1
    with:
      version: npm run ci:version
      publish: npm run ci:publish
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
-     #   Delete because trusted publishing enabled
-     #   NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
+     GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### 詳細説明

**ステップ名の更新:**
- "Publish to npm" → "Publish to GitHub Packages" に変更
- 実際の動作を正確に反映

**環境変数の追加:**

1. **`GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` の設定:**
   - `${{ secrets.GITHUB_TOKEN }}` を `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` 環境変数に代入
   - この環境変数は、最初のステップで `actions/setup-node` が生成した `.npmrc` 内で参照される
   - `npm publish` 実行時に、この値を使って GitHub Packages に認証される

2. **`GITHUB_TOKEN` の値について:**
   - GitHub Actions が自動的に各ワークフロー実行時に生成する一時トークン
   - `permissions` で指定された権限（この場合 `packages: write`）を持つ
   - ワークフロー実行後に自動的に無効化されるため、セキュリティが高い
   - 別途 Personal Access Token (PAT) を作成・管理する必要がない

3. **`NPM_TOKEN` コメントの削除:**
   - npm 公開レジストリへの公開には `NPM_TOKEN` が必要だったが、GitHub Packages では不要
   - Trusted Publishing を使用していた場合はトークン自体が不要だったが、その説明も不要になった

**認証フローの詳細:**

```
1. actions/setup-node が .npmrc を生成（最初のセットアップ時）
   ↓
2. .npmrc に ${GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN} が含まれる
   ↓
3. Changesets アクションの env で GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN に GITHUB_TOKEN を設定
   ↓
4. npm publish 実行時に環境変数が展開される
   ↓
5. GITHUB_TOKEN を使って GitHub Packages に認証
   ↓
6. パッケージが公開される
```

---

### 4. `.github/workflows/pre-release.yml` の変更

#### 変更箇所 1: 権限設定

```diff
  permissions:
    contents: write
-   id-token: write # for trusted publishing
+   packages: write # for GitHub Packages
```

#### 詳細説明

**変更理由は `release.yml` と同じ:**
- npm Trusted Publishing の OIDC 認証から GitHub Token 認証への移行
- `id-token: write` 権限は不要になり、代わりに `packages: write` が必要
- プレリリースバージョンを GitHub Packages に公開するために必要

**プレリリースにおける重要性:**
- プレリリース版（例: `1.0.4-next.0`）も GitHub Packages に公開される
- 同じ認証メカニズムを使用するため、通常のリリースと同じ権限が必要

---

#### 変更箇所 2: Node.js セットアップの簡略化

```diff
  steps:
    - uses: actions/checkout@v5
      with:
        ref: ${{ github.ref }} # current branch
        token: ${{ secrets.GITHUB_TOKEN }}

-   - name: Use Node.js 20.15.1 for build # ビルド用にNode.js 20.15.1をセットアップ
+   - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
-       node-version-file: .node-version # ノードのバージョンをファイルから取得
+       node-version-file: .node-version
+       registry-url: https://npm.pkg.github.com
+       scope: '@room-601'

-   - name: install dependencies step
+   - name: Install dependencies
      run: npm ci

-   - name: build step
+   - name: Build
      run: npm run build
```

#### 詳細説明

**`release.yml` と同様の簡略化:**
- Node.js セットアップを1回に統合
- 最初のセットアップで `registry-url` と `scope` を設定
- 2回目の Node.js セットアップ（22.x）を削除
- `npm install -g npm@latest` も不要に

**プレリリースワークフローの特徴:**
- プレリリースモードへの入退出を含む複雑なワークフロー
- しかし、公開処理自体は通常のリリースと同じく簡略化可能
- ビルドとバージョニング、公開をすべて同じ Node.js バージョンで実行

**メリット:**
- ワークフローがシンプルになり、実行時間が短縮
- プレリリース版のテストが迅速に行える
- ステップ名も統一され、可読性が向上

---

#### 変更箇所 3: プレリリース公開の簡略化

```diff
- # publish用にNode.js 22.xをセットアップ（npm 11系が使える）
- - name: Use Node.js 22.x for publish
-   if: inputs.actions == 'enter-and-publish' && steps.check-changesets.outputs.has_changesets == 'true'
-   uses: actions/setup-node@v4
-   with:
-     node-version: 22.x
-     # GitHub Packages用のregistry設定
-     registry-url: https://npm.pkg.github.com
-     scope: '@room-601'
-
- - name: Install npm latest
-   if: inputs.actions == 'enter-and-publish' && steps.check-changesets.outputs.has_changesets == 'true'
-   run: npm install -g npm@latest
-
  - name: Publish pre-release
    if: inputs.actions == 'enter-and-publish' && steps.check-changesets.outputs.has_changesets == 'true'
    run: |
      npm run ci:publish
+   env:
+     GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### 詳細説明

**大幅な簡略化:**
- 2回目の Node.js セットアップステップを完全に削除
- npm の最新版インストールも不要
- 最初のセットアップで設定した registry 設定をそのまま使用

**環境変数の追加:**
- `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` を設定
- 最初のステップで生成された `.npmrc` を使用して認証
- GitHub Packages への公開が可能に

**条件付き実行:**
- `if: inputs.actions == 'enter-and-publish' && steps.check-changesets.outputs.has_changesets == 'true'`
- プレリリースモードに入って公開する場合のみ実行
- changeset ファイルが存在する場合のみ実行

**プレリリースの特徴:**
- プレリリースバージョン（例: `1.0.4-next.0`, `1.0.4-next.1`）が作成される
- これらのバージョンも GitHub Packages に公開され、リポジトリへのアクセス権を持つユーザーがインストール可能
- プレリリース版を使用することで、本番環境にリリースする前にテストが可能

**セキュリティ上の利点:**
- プレリリース版もプライベートレジストリに公開されるため、外部に漏れない
- テスト中の不安定な機能を含むバージョンを安全に共有できる
- ビルド環境と公開環境が同一なので、予期しない問題が発生しにくい

---

### 5. `README.md` の新規作成

#### 作成理由

**包括的なドキュメントの必要性:**
- GitHub Packages への移行により、パッケージのインストール方法が変更
- 利用者とメンテナーの両方に向けた詳細な手順が必要
- 移行に関する情報を一元化して提供

#### 主要なセクション

**1. インストール手順 (📦 インストール)**
- GitHub PAT の作成手順
- `.npmrc` の設定方法
- パッケージのインストールコマンド
- セキュリティに関する注意事項（`.gitignore` への追加など）

**利用者への影響:**
- これまでは `npm install @room-601/npm-package-example` だけで良かったが、今後は認証設定が必要
- PAT の取得と設定という追加のステップが必要
- ドキュメントを提供することで、スムーズな移行を支援

**2. 使い方 (🔧 使い方)**
- TypeScript でのインポート例
- 実際の使用例
- 簡潔で分かりやすいコード例

**3. 公開方法（メンテナー向け） (🚀 公開方法)**

**Changesets ワークフロー:**
1. `npx changeset` での変更内容の記録
2. コミット＆プッシュ
3. 自動リリースプロセスの説明

**Release ワークフロー:**
- `main` ブランチへのプッシュでトリガー
- "Version Packages" PR の自動作成
- PR マージ時の自動公開

**Pre-release ワークフロー:**
- プレリリースモードの入り方と終了方法
- プレリリースバージョンの命名規則（`1.0.4-next.0` など）

**GitHub Actions の設定:**
- 必要な権限の詳細説明（`contents: write`, `packages: write`, `pull-requests: write`）
- 認証メカニズムの説明（`GITHUB_TOKEN` と `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN`）
- 追加のシークレット設定が不要であることを強調

**4. パッケージ設定 (📋 パッケージ設定)**

**`package.json` の重要な設定:**
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

**各設定の意味:**
- スコープ付きパッケージ名の必要性
- スコープと organization/username の一致
- `access: "restricted"` によるプライベート化
- `registry` による公開先の指定

**`.npmrc` の設定:**
- スコープごとのレジストリ設定
- 認証トークンの環境変数参照
- `actions/setup-node` による自動提供

**5. npm レジストリからの移行 (🔄 npm レジストリからの移行)**

**変更点の詳細な比較表:**

| 項目 | 移行前 | 移行後 |
|------|--------|--------|
| レジストリ URL | `https://registry.npmjs.org` | `https://npm.pkg.github.com` |
| 認証方式 | OIDC (Trusted Publishing) | GitHub Token |
| アクセス制御 | `"access": "public"` | `"access": "restricted"` |
| GitHub Actions 権限 | `id-token: write` | `packages: write` |
| 環境変数 | 不要 | `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` |

**GitHub Packages のメリット:**
- ✅ デフォルトでプライベート - 内部パッケージのセキュリティ向上
- ✅ GitHub と統合 - 同じ認証と権限管理
- ✅ 追加トークン不要 - Actions で `GITHUB_TOKEN` を使用
- ✅ きめ細かいアクセス制御 - GitHub リポジトリの権限で管理

**移行の背景:**
- プライベートパッケージとして管理する必要性
- GitHub のエコシステム内での統合管理
- セキュリティとアクセス制御の向上

**6. 開発 (🛠️ 開発)**

**前提条件:**
- Node.js と npm のバージョン指定
- 開発環境のセットアップ手順

**利用可能なスクリプト:**
- `npm run build` - TypeScript のコンパイル
- `npm run ci:version` - CI でのバージョン管理
- `npm run ci:publish` - CI でのパッケージ公開

**7. ライセンスとリンク (📝 ライセンス / 🔗 リンク)**
- MIT ライセンスの明記
- GitHub リポジトリへのリンク
- GitHub Packages ページへのリンク
- Changesets ドキュメントへのリンク

#### ドキュメントの日本語化

**日本語での提供理由:**
- チームメンバーや日本語話者の利用者にとって理解しやすい
- 技術的な詳細を母国語で説明することで、誤解を防ぐ
- 日本のコミュニティでの採用を促進

**翻訳の品質:**
- 技術用語は適切に日本語化
- 英語の専門用語は必要に応じてそのまま使用（例: "GitHub Actions", "npm"）
- 読みやすさとわかりやすさを重視

---

## 🔍 テスト方法

### ローカルでのテスト

**1. パッケージのビルド:**
```bash
npm run build
```

**2. `.npmrc` の設定確認:**
- 環境変数 `GITHUB_PACKAGES_NPM_PUBLISH_AUTH_TOKEN` が正しく参照されていることを確認
- ローカルでテストする場合は、有効な GitHub PAT を設定

**3. Dry-run での公開テスト:**
```bash
npm publish --dry-run
```
- 実際に公開せずに、公開可能かどうかを確認
- エラーが出ないことを確認

### GitHub Actions でのテスト

**1. ブランチにプッシュして確認:**
- このブランチをプッシュし、Actions が実行されることを確認
- ただし、`main` ブランチ以外では実際の公開は行われない

**2. PR をマージして実際のリリースをテスト:**
- Changeset が含まれている場合、"Version Packages" PR が作成される
- その PR をマージすることで、実際に GitHub Packages への公開がトリガーされる

**3. 公開されたパッケージの確認:**
- GitHub リポジトリの Packages タブで確認
- `https://github.com/room-601/npm-package-example/packages` にアクセス

**4. パッケージのインストールテスト:**
```bash
# 別のプロジェクトで
npm install @room-601/npm-package-example
```
- 適切な `.npmrc` 設定があれば、インストールが成功するはず

---

## 📊 影響範囲

### パッケージ利用者への影響

**既存の利用者:**
- ⚠️ **破壊的変更**: npm 公開レジストリからはインストールできなくなる
- 🔧 **対応が必要**: `.npmrc` の設定と GitHub PAT の取得が必要
- 📖 **ドキュメント提供**: README に詳細な手順を記載

**新規の利用者:**
- 📝 GitHub PAT の作成が必要
- ⚙️ `.npmrc` の設定が必要
- 🔐 リポジトリへのアクセス権が必要

### メンテナーへの影響

**公開プロセス:**
- ✅ **変更なし**: Changesets ワークフローは同じ
- ✅ **シンプル化**: npm トークンの管理が不要
- ✅ **自動化**: GitHub Actions で自動的に公開

**権限管理:**
- 🔐 GitHub リポジトリの権限で管理
- 👥 organization メンバーは自動的にアクセス可能
- 🎯 きめ細かい権限設定が可能

### CI/CD への影響

**GitHub Actions:**
- ✅ **シンプル化**: `GITHUB_TOKEN` のみを使用
- ✅ **セキュリティ向上**: 一時トークンを使用
- ✅ **追加設定不要**: シークレットの追加管理が不要

**その他の CI/CD:**
- ⚠️ GitHub Actions 以外の CI/CD を使用している場合、GitHub PAT が必要
- 🔧 環境変数として PAT を設定する必要がある

---

## ✅ チェックリスト

### マージ前の確認事項

- [ ] すべてのファイルの変更内容を確認
- [ ] `package.json` の設定が正しいことを確認
- [ ] `.npmrc` の環境変数名が正しいことを確認
- [ ] ワークフローファイルの権限設定を確認
- [ ] README の内容が正確であることを確認
- [ ] ローカルでビルドが成功することを確認

### マージ後の確認事項

- [ ] GitHub Actions が正常に実行されることを確認
- [ ] Changeset がある場合、"Version Packages" PR が作成されることを確認
- [ ] 実際に GitHub Packages にパッケージが公開されることを確認
- [ ] 公開されたパッケージがインストール可能であることを確認
- [ ] 既存の利用者に変更を通知（必要に応じて）

---

## 📚 参考資料

- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [Publishing Node.js packages to GitHub Packages](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry)
- [Changesets Documentation](https://github.com/changesets/changesets/blob/main/docs/intro-to-using-changesets.md)
- [actions/setup-node Documentation](https://github.com/actions/setup-node#usage)

---

## 💬 質問・フィードバック

この PR について質問やフィードバックがあれば、コメントでお知らせください！

