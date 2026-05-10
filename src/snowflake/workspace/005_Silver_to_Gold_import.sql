/*
name: 005_Silver_to_Gold_imports.sql
description: SILVERの特徴量データでMLモデルを学習・予測してGOLDに書き込むストアドプロシージャ（imports版）
前提: predict.py を @TITANIC_DB.STAGE.STG_TITANIC/python/ にアップロード済みであること
*/
-- セッション設定
USE ROLE SYSADMIN;
USE DATABASE TITANIC_DB;
USE SCHEMA TITANIC_DB.GOLD;
USE WAREHOUSE TITANIC_WH;

-- predict.pyをSTAGEにアップロード（SnowSQL CLIで実行）
-- PUT file:///path/to/predict.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE;

-- GOLDテーブルの作成
CREATE TABLE IF NOT EXISTS TITANIC_DB.GOLD.PREDICTION_TITANIC (
  PASSENGERID         INT     COMMENT '乗客ID',
  SURVIVED_ACTUAL     INT     COMMENT '実際の生存フラグ（0: 死亡, 1: 生存）',
  SURVIVED_PREDICTED  INT     COMMENT '予測した生存フラグ（0: 死亡, 1: 生存）',
  SURVIVAL_PROB       FLOAT   COMMENT '生存確率（0.0〜1.0）',
  IS_CORRECT          BOOLEAN COMMENT '予測が正解かどうか'
)
COMMENT = 'タイタニック乗客データ（ML予測結果）';

-- ストアドプロシージャの作成
CREATE OR REPLACE PROCEDURE TITANIC_DB.GOLD.SP_SILVER_TO_GOLD()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python', 'pandas', 'scikit-learn')
  IMPORTS = ('@TITANIC_DB.STAGE.STG_TITANIC/python/predict.py')
  HANDLER = 'predict.main'
AS '';

-- ストアドプロシージャの実行
CALL TITANIC_DB.GOLD.SP_SILVER_TO_GOLD();

-- 確認
SELECT * FROM TITANIC_DB.GOLD.PREDICTION_TITANIC LIMIT 10;
SELECT COUNT(*) AS ROW_COUNT FROM TITANIC_DB.GOLD.PREDICTION_TITANIC;
