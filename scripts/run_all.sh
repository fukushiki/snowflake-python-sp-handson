#!/usr/bin/env bash
# =============================================================================
# run_all.sh
# Snowflake CLIを使ってTITANICプロジェクトのパイプラインを一括実行する
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_DIR="$ROOT_DIR/src/snowflake/workspace"
PYTHON_DIR="$ROOT_DIR/src/snowflake/python"
DATA_DIR="$ROOT_DIR/data"
CONNECTION="python-stored-procedure"

# -----------------------------------------------------------------------------
# 前提チェック
# -----------------------------------------------------------------------------
if ! command -v snow >/dev/null 2>&1; then
  echo "error: Snowflake CLI が見つかりません。"
  echo "hint : pip install snowflake-cli-labs"
  exit 1
fi

# コネクション確認
if ! snow connection test --connection "$CONNECTION" >/dev/null 2>&1; then
  echo "error: Snowflake コネクション '$CONNECTION' に接続できません。"
  echo "hint : snow connection list で接続一覧を確認してください。"
  exit 1
fi

echo "======================================================"
echo " TITANIC Pipeline 実行開始"
echo " CONNECTION: $CONNECTION"
echo "======================================================"

# -----------------------------------------------------------------------------
# Step 1: 環境セットアップ
# -----------------------------------------------------------------------------
echo "[1/6] 001_Setup.sql を実行中..."
snow sql -f "$WORKSPACE_DIR/001_Setup.sql" --connection "$CONNECTION"
echo "      完了"

# -----------------------------------------------------------------------------
# Step 2: STAGEとFILE FORMAT作成
# -----------------------------------------------------------------------------
echo "[2/6] 002_LoadStage.sql を実行中..."
snow sql -f "$WORKSPACE_DIR/002_LoadStage.sql" --connection "$CONNECTION"
echo "      完了"

# -----------------------------------------------------------------------------
# Step 3: CSVをSTAGEにアップロード
# -----------------------------------------------------------------------------
echo "[3/6] CSVをSTAGEにアップロード中..."
snow sql -q "PUT file://$DATA_DIR/Titanic-Dataset.csv @TITANIC_DB.STAGE.STG_TITANIC/data/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection "$CONNECTION"
echo "      完了"

# -----------------------------------------------------------------------------
# Step 4: STAGEからBRONZEにロード
# -----------------------------------------------------------------------------
echo "[4/6] 003_Stage_to_Bronze.sql を実行中..."
snow sql -f "$WORKSPACE_DIR/003_Stage_to_Bronze.sql" --connection "$CONNECTION"
echo "      完了"

# -----------------------------------------------------------------------------
# Step 5: PythonファイルをSTAGEにアップロード
# -----------------------------------------------------------------------------
echo "[5/6] Pythonファイルをアップロード中..."
snow sql -q "PUT file://$PYTHON_DIR/transform.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection "$CONNECTION"
snow sql -q "PUT file://$PYTHON_DIR/predict.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection "$CONNECTION"
echo "      完了"

# -----------------------------------------------------------------------------
# Step 6: ストアドプロシージャ実行
# -----------------------------------------------------------------------------
echo "[6/6] ストアドプロシージャを実行中..."
snow sql -f "$WORKSPACE_DIR/004_Bronze_to_Silver_import.sql" --connection "$CONNECTION"
echo "      BRONZE → SILVER 完了"
snow sql -f "$WORKSPACE_DIR/005_Silver_to_Gold_import.sql" --connection "$CONNECTION"
echo "      SILVER → GOLD 完了"

echo "======================================================"
echo " 全処理完了！"
echo "======================================================"