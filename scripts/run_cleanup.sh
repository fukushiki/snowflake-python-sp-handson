#!/usr/bin/env bash
# =============================================================================
# run_cleanup.sh
# Snowflake CLIを使ってTITANICプロジェクトのクリーンアップSQLを実行する
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_DIR="$ROOT_DIR/src/snowflake/workspace"

# -----------------------------------------------------------------------------
# 前提チェック
# -----------------------------------------------------------------------------
if ! command -v snow >/dev/null 2>&1; then
  echo "error: Snowflake CLI が見つかりません。"
  echo "hint : pip install snowflake-cli-labs"
  exit 1
fi

# コネクション一覧を取得して選択
CONNECTIONS=()
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r connection_name; do
    CONNECTIONS+=("$connection_name")
  done < <(
    snow connection list --format JSON 2>/dev/null \
      | jq -r '.[] | .connection_name // empty' \
      | sed '/^[[:space:]]*$/d'
  )
else
  while IFS= read -r connection_name; do
    CONNECTIONS+=("$connection_name")
  done < <(
    snow connection list --format CSV 2>/dev/null \
      | tail -n +2 \
      | cut -d',' -f1 \
      | sed 's/^"//; s/"$//' \
      | sed '/^[[:space:]]*$/d'
  )
fi

if [[ ${#CONNECTIONS[@]} -eq 0 ]]; then
  echo "error: 利用可能な Snowflake connection が見つかりません。"
  echo "hint : snow connection add を実行して connection を作成してください。"
  exit 1
fi

echo "利用する Snowflake connection を選択してください:"
for i in "${!CONNECTIONS[@]}"; do
  printf "  %d) %s\n" "$((i + 1))" "${CONNECTIONS[$i]}"
done
echo "  0) リストにない（connectionを設定する）"

read -r -p "選択番号: " CONNECTION_INDEX
if [[ "$CONNECTION_INDEX" == "0" ]]; then
  echo "snow connection add を実行して connection を設定してから再実行してください。"
  exit 1
fi

if [[ "$CONNECTION_INDEX" =~ ^[0-9]+$ ]] && (( CONNECTION_INDEX >= 1 && CONNECTION_INDEX <= ${#CONNECTIONS[@]} )); then
  CONNECTION="${CONNECTIONS[$((CONNECTION_INDEX - 1))]}"
else
  echo "error: 無効な選択です。"
  exit 1
fi

# コネクション確認
if ! snow connection test --connection "$CONNECTION" >/dev/null 2>&1; then
  echo "error: Snowflake コネクション '$CONNECTION' に接続できません。"
  echo "hint : snow connection list で接続一覧を確認してください。"
  exit 1
fi

echo "======================================================"
echo " TITANIC Cleanup 実行開始"
echo " CONNECTION: $CONNECTION"
echo "======================================================"

echo "[1/1] 999_Cleanup.sql を実行中..."
snow sql -f "$WORKSPACE_DIR/999_Cleanup.sql" --connection "$CONNECTION"
echo "      完了"

echo "======================================================"
echo " クリーンアップ完了！"
echo "======================================================"
