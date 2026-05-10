# =============================================================================
# run_all.ps1
# Snowflake CLIを使ってTITANICプロジェクトのパイプラインを一括実行する
# =============================================================================
$ErrorActionPreference = "Stop"

$ROOT_DIR     = (Resolve-Path "$PSScriptRoot\..").Path
$WORKSPACE_DIR = "$ROOT_DIR\src\snowflake\workspace"
$PYTHON_DIR   = "$ROOT_DIR\src\snowflake\python"
$DATA_DIR     = "$ROOT_DIR\data"
$CONNECTION   = "python-stored-procedure"

# -----------------------------------------------------------------------------
# 前提チェック
# -----------------------------------------------------------------------------
if (-not (Get-Command snow -ErrorAction SilentlyContinue)) {
  Write-Error "error: Snowflake CLI が見つかりません。"
  Write-Host  "hint : pip install snowflake-cli-labs"
  exit 1
}

# コネクション確認
try {
  snow connection test --connection $CONNECTION | Out-Null
} catch {
  Write-Error "error: Snowflake コネクション '$CONNECTION' に接続できません。"
  Write-Host  "hint : snow connection list で接続一覧を確認してください。"
  exit 1
}

Write-Host "======================================================"
Write-Host " TITANIC Pipeline 実行開始"
Write-Host " CONNECTION: $CONNECTION"
Write-Host "======================================================"

# -----------------------------------------------------------------------------
# Step 1: 環境セットアップ
# -----------------------------------------------------------------------------
Write-Host "[1/6] 001_Setup.sql を実行中..."
snow sql -f "$WORKSPACE_DIR\001_Setup.sql" --connection $CONNECTION
Write-Host "      完了"

# -----------------------------------------------------------------------------
# Step 2: STAGEとFILE FORMAT作成
# -----------------------------------------------------------------------------
Write-Host "[2/6] 002_LoadStage.sql を実行中..."
snow sql -f "$WORKSPACE_DIR\002_LoadStage.sql" --connection $CONNECTION
Write-Host "      完了"

# -----------------------------------------------------------------------------
# Step 3: CSVをSTAGEにアップロード
# -----------------------------------------------------------------------------
Write-Host "[3/6] CSVをSTAGEにアップロード中..."
snow sql -q "PUT file://$DATA_DIR/Titanic-Dataset.csv @TITANIC_DB.STAGE.STG_TITANIC/data/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection $CONNECTION
Write-Host "      完了"

# -----------------------------------------------------------------------------
# Step 4: STAGEからBRONZEにロード
# -----------------------------------------------------------------------------
Write-Host "[4/6] 003_Stage_to_Bronze.sql を実行中..."
snow sql -f "$WORKSPACE_DIR\003_Stage_to_Bronze.sql" --connection $CONNECTION
Write-Host "      完了"

# -----------------------------------------------------------------------------
# Step 5: PythonファイルをSTAGEにアップロード
# -----------------------------------------------------------------------------
Write-Host "[5/6] Pythonファイルをアップロード中..."
snow sql -q "PUT file://$PYTHON_DIR/transform.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection $CONNECTION
snow sql -q "PUT file://$PYTHON_DIR/predict.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" --connection $CONNECTION
Write-Host "      完了"

# -----------------------------------------------------------------------------
# Step 6: ストアドプロシージャ実行
# -----------------------------------------------------------------------------
Write-Host "[6/6] ストアドプロシージャを実行中..."
snow sql -f "$WORKSPACE_DIR\004_Bronze_to_Silver_import.sql" --connection $CONNECTION
Write-Host "      BRONZE → SILVER 完了"
snow sql -f "$WORKSPACE_DIR\005_Silver_to_Gold_import.sql" --connection $CONNECTION
Write-Host "      SILVER → GOLD 完了"

Write-Host "======================================================"
Write-Host " 全処理完了！"
Write-Host "======================================================"