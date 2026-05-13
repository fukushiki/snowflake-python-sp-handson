# =============================================================================
# run_cleanup.ps1
# Snowflake CLIを使ってTITANICプロジェクトのクリーンアップSQLを実行する
# =============================================================================
$ErrorActionPreference = "Stop"

$ROOT_DIR      = (Resolve-Path "$PSScriptRoot\..").Path
$WORKSPACE_DIR = "$ROOT_DIR\src\snowflake\workspace"

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
Write-Host " TITANIC Cleanup 実行開始"
Write-Host " CONNECTION: $CONNECTION"
Write-Host "======================================================"

Write-Host "[1/1] 999_Cleanup.sql を実行中..."
snow sql -f "$WORKSPACE_DIR\999_Cleanup.sql" --connection $CONNECTION
Write-Host "      完了"

Write-Host "======================================================"
Write-Host " クリーンアップ完了！"
Write-Host "======================================================"
