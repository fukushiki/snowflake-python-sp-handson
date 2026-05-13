# =============================================================================
# run_all.ps1
# Snowflake CLIを使ってTITANICプロジェクトのパイプラインを一括実行する
# =============================================================================
$ErrorActionPreference = "Stop"

$ROOT_DIR     = (Resolve-Path "$PSScriptRoot\..").Path
$WORKSPACE_DIR = "$ROOT_DIR\src\snowflake\workspace"
$PYTHON_DIR   = "$ROOT_DIR\src\snowflake\python"
$DATA_DIR     = "$ROOT_DIR\data"

# -----------------------------------------------------------------------------
# 前提チェック
# -----------------------------------------------------------------------------
if (-not (Get-Command snow -ErrorAction SilentlyContinue)) {
  Write-Error "error: Snowflake CLI が見つかりません。"
  Write-Host  "hint : pip install snowflake-cli-labs"
  exit 1
}

# コネクション一覧を取得して選択
try {
  $connections = @(
    snow connection list --format CSV |
      ConvertFrom-Csv |
      ForEach-Object { $_.connection_name } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  )
} catch {
  Write-Error "error: Snowflake connection 一覧の取得に失敗しました。"
  exit 1
}

if ($connections.Count -eq 0) {
  Write-Error "error: 利用可能な Snowflake connection が見つかりません。"
  Write-Host  "hint : snow connection add を実行して connection を作成してください。"
  exit 1
}

Write-Host "利用する Snowflake connection を選択してください:"
for ($i = 0; $i -lt $connections.Count; $i++) {
  Write-Host ("  {0}) {1}" -f ($i + 1), $connections[$i])
}
Write-Host "  0) リストにない（connectionを設定する）"

$selection = Read-Host "選択番号"
if ($selection -eq "0") {
  Write-Host "snow connection add を実行して connection を設定してから再実行してください。"
  exit 1
}

$selectedIndex = 0
if (-not [int]::TryParse($selection, [ref]$selectedIndex) -or $selectedIndex -lt 1 -or $selectedIndex -gt $connections.Count) {
  Write-Error "error: 無効な選択です。"
  exit 1
}

$CONNECTION = $connections[$selectedIndex - 1]

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
