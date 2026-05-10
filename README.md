---
name: README
description: fukushiki/snowflake-python-sp-handsonのREADME
origin: fukushiki/snowflake-python-sp-handson
type: README
---

# snowflake-python-sp-handson

SnowflakeのStored Procedure機能を利用したPython実装について学ぶためのリポジトリです。  
Ka
詳しい内容はZennに書いた記事[xxx](xxx)を参考にしてください。  


## ディレクトリ構成

```txt
.
└── Py-Stored-Procedure/
    ├── data/
    │   └── Titanic-Dataset.csv         # fetch_titanic_csv* で取得
    ├── scripts/
    │   ├── fetch_titanic_csv.sh        # Kaggle からデータ取得 (Mac/Linux)
    │   ├── fetch_titanic_csv.ps1       # Kaggle からデータ取得 (Windows)
    │   ├── run_all.sh                  # パイプライン一括実行 (Mac/Linux)
    │   └── run_all.ps1                 # パイプライン一括実行 (Windows)
    ├── src/
    │   └── snowflake/
    │       ├── python/
    │       │   ├── transform.py        # BRONZE → SILVER 変換ロジック
    │       │   └── predict.py          # SILVER → GOLD 予測ロジック
    │       └── workspace/
    │           ├── 001_Setup.sql           # DB / Schema / WH 作成
    │           ├── 002_LoadStage.sql        # Stage / File Format 作成
    │           ├── 003_Stage_to_Bronze.sql  # COPY INTO → RAW_TITANIC
    │           ├── 004_Bronze_to_Silver_inline.sql  # SP (インライン定義)
    │           ├── 004_Bronze_to_Silver_import.sql  # SP (IMPORTS 方式)
    │           ├── 005_Silver_to_Gold_import.sql    # SP (IMPORTS 方式)
    │           └── 999_Cleanup.sql         # 全オブジェクト削除
    └── README.md

```

## ライセンス
- Dataset: `yasserh/titanic-dataset`
- License: `CC0: Public Domain (CC0-1.0)`
- URL: [Kaggle - yasserh/titanic-dataset](https://www.kaggle.com/datasets/yasserh/titanic-dataset)
- 注意: 規約はKaggleデータセットページの表示を優先する


## Setup: Snowflake CLI

Snowflake CLIをインストールし、`snow` コマンドを利用できるようにする。  

### Install

#### Mac

```bash
brew tap snowflakedb/snowflake-cli
brew update
brew install snowflake-cli
```

インストール確認:

```bash
snow --version
snow --help
```

#### Windows

Windowsでは、Snowflake CLIのインストーラーを使用することが推奨されている。

インストール後の確認:

```powershell
snow --version
snow --help
```

### 接続設定の追加

```bash
snow connection add
```

対話形式で最低限以下を入力する。

```text
Enter connection name: <connection-name>
Enter account: <account-identifier> # Account Details の Account Identifier
Enter user: <user>                  # ログイン名
Enter password: <password>          # 上記ログイン名でログインする password

# 以下は省略可
Enter role:
Enter warehouse:
Enter database:
Enter schema:
Enter host:
Enter port:
Enter region:
Enter authenticator:
Enter workload identity provider:
Enter private key file:
Enter token file path:
Wrote new connection <connection-name> to <filepath>
```

`role` / `warehouse` / `database` / `schema` などは、後続のセットアップSQLで明示的に指定するため、初期設定では未入力でもよい。

### 接続設定ファイルの配置場所

#### Mac

```text
/Users/<username>/.snowflake/connections.toml
```

#### Windows

```text
C:\Users\<username>\.snowflake\connections.toml
```

### 接続設定の確認

```bash
snow connection list
snow connection test --connection <connection-name>
snow sql -q "select current_version();" --connection <connection-name>
```