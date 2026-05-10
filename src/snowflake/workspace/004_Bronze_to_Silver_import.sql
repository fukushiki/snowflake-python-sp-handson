/*
name: 004_Bronze_to_Silver_import.sql
description: BRONZEの生データをクレンジング・加工してSILVERに書き込むストアドプロシージャ（import版）
前提: transform.py を @TITANIC_DB.STAGE.STG_TITANIC/python/ にアップロード済みであること
*/
-- セッション設定
USE ROLE SYSADMIN;
USE DATABASE TITANIC_DB;
USE SCHEMA TITANIC_DB.SILVER;
USE WAREHOUSE TITANIC_WH;

-- transform.pyをSTAGEにアップロード（SnowSQL CLIで実行）
-- PUT file:///path/to/transform.py @TITANIC_DB.STAGE.STG_TITANIC/python/ OVERWRITE = TRUE;

-- SILVERテーブルの作成
CREATE TABLE IF NOT EXISTS TITANIC_DB.SILVER.FEATURE_TITANIC (
  PASSENGERID   INT        COMMENT '乗客ID',
  SURVIVED      INT        COMMENT '生存フラグ（0: 死亡, 1: 生存）',
  PCLASS        INT        COMMENT '客室クラス（1: 1等, 2: 2等, 3: 3等）',
  SEX_ENCODED   INT        COMMENT '性別（0: female, 1: male）',
  AGE           FLOAT      COMMENT '年齢（欠損値は中央値で補完）',
  SIBSP         INT        COMMENT '兄弟・配偶者の数',
  PARCH         INT        COMMENT '親・子供の数',
  FARE          FLOAT      COMMENT '運賃',
  EMBARKED_C    INT        COMMENT '乗船港 Cherbourg（One-hot）',
  EMBARKED_Q    INT        COMMENT '乗船港 Queenstown（One-hot）',
  EMBARKED_S    INT        COMMENT '乗船港 Southampton（One-hot）'
)
COMMENT = 'タイタニック乗客データ（クレンジング・特徴量エンジニアリング済み）';

-- ストアドプロシージャの作成
CREATE OR REPLACE PROCEDURE TITANIC_DB.SILVER.SP_BRONZE_TO_SILVER()
  RETURNS STRING
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python', 'pandas')
  IMPORTS = ('@TITANIC_DB.STAGE.STG_TITANIC/python/transform.py')
  HANDLER = 'transform.main'
  EXECUTE AS CALLER
AS '';

-- ストアドプロシージャの実行
CALL TITANIC_DB.SILVER.SP_BRONZE_TO_SILVER();

-- 確認
SELECT * FROM TITANIC_DB.SILVER.FEATURE_TITANIC LIMIT 10;
SELECT COUNT(*) AS ROW_COUNT FROM TITANIC_DB.SILVER.FEATURE_TITANIC;