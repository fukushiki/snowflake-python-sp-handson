---
name: README
description: fukushiki/snowflake-python-sp-handsonのREADME
origin: fukushiki/snowflake-python-sp-handson
type: README
---

# snowflake-python-sp-handson

SnowflakeのStored Procedure機能を利用したPython実装について学ぶためのリポジトリです。  
Titanicデータセットを用いてSnowflakeのStored Procedure機能(Python実行)を学ぶことができます。  
詳しい内容はZennに書いた記事[xxx](xxx)を参考にしてください。  


## ディレクトリ構成

```txt
.
├── data/
│   └── Titanic-Dataset.csv             # fetch_titanic_csv* で取得
├── scripts/
│   ├── fetch_titanic_csv.sh            # Kaggle からデータ取得 (Mac/Linux)
│   ├── fetch_titanic_csv.ps1           # Kaggle からデータ取得 (Windows)
│   ├── run_all.sh                      # パイプライン一括実行 (Mac/Linux)
│   ├── run_all.ps1                     # パイプライン一括実行 (Windows)
│   ├── run_cleanup.sh                  # クリーンアップ実行 (Mac/Linux)
│   └── run_cleanup.ps1                 # クリーンアップ実行 (Windows)
├── src/
│   └── snowflake/
│       ├── python/
│       │   ├── transform.py            # BRONZE → SILVER 変換ロジック
│       │   └── predict.py              # SILVER → GOLD 予測ロジック
│       └── workspace/
│           ├── 001_Setup.sql           # DB / Schema / WH 作成
│           ├── 002_LoadStage.sql       # Stage / File Format 作成
│           ├── 003_Stage_to_Bronze.sql # COPY INTO → RAW_TITANIC
│           ├── 004_Bronze_to_Silver_inline.sql  # SP (インライン定義)
│           ├── 004_Bronze_to_Silver_import.sql  # SP (IMPORTS 方式)
│           ├── 005_Silver_to_Gold_import.sql    # SP (IMPORTS 方式)
│           └── 999_Cleanup.sql         # 全オブジェクト削除
└── README.md

```

## データレイヤー構成

メダリオンアーキテクチャ（STAGE → BRONZE → SILVER → GOLD）を採用しています。

| レイヤー | スキーマ | テーブル | 内容 |
|---|---|---|---|
| STAGE | `STAGE` | `STG_TITANIC` | CSV・Pythonファイルを格納する内部ステージ |
| BRONZE | `BRONZE` | `RAW_TITANIC` | ステージから COPY INTO した生データ |
| SILVER | `SILVER` | `FEATURE_TITANIC` | 欠損補完・エンコードを行った特徴量テーブル |
| GOLD | `GOLD` | `PREDICTION_TITANIC` | 機械学習モデルによる生存予測結果 |

各レイヤー間の変換は Python Stored Procedure（`SP_BRONZE_TO_SILVER`, `SP_SILVER_TO_GOLD`）で実装しています。

## データセットのライセンス
このProjectではKaggleのtitanicデータセットを利用しています。  
`scripts/fetch_titanic_csv.sh`(もしくは`.ps1`)を用いてダウンロードしてきてください。
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

## Snowflake CLI実行例

Snowsight（Worksheet）で確認済みの手順を、以下のCLIで再現する。  
これらの内容をまとめたものが `scripts/run_all`（sh/ps1）に記載されている。

```bash
# 接続確認
snow connection test --connection <connection-name>

# 1) 環境セットアップ
snow sql -f src/snowflake/workspace/001_Setup.sql --connection <connection-name>

# 2) STAGE/FILE FORMAT作成
snow sql -f src/snowflake/workspace/002_LoadStage.sql --connection <connection-name>

# 3) CSVアップロード（STAGE/ステージ/data）
snow sql -q "PUT file://data/Titanic-Dataset.csv @TITANIC_DB.STAGE.STG_TITANIC/data/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection <connection-name>

# 4) STAGE -> BRONZE
snow sql -f src/snowflake/workspace/003_Stage_to_Bronze.sql --connection <connection-name>

# 5) Pythonアップロード（STAGE/ステージ/python）
snow sql -q "PUT file://src/snowflake/python/transform.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection <connection-name>
snow sql -q "PUT file://src/snowflake/python/predict.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection <connection-name>

# 6) BRONZE -> SILVER
snow sql -f src/snowflake/workspace/004_Bronze_to_Silver_import.sql --connection <connection-name>

# 7) SILVER -> GOLD
snow sql -f src/snowflake/workspace/005_Silver_to_Gold_import.sql --connection <connection-name>
```

クリーンアップは以下で実行できる。

```bash
# Mac/Linux
./scripts/run_cleanup.sh

# Windows PowerShell
.\scripts\run_cleanup.ps1
```
