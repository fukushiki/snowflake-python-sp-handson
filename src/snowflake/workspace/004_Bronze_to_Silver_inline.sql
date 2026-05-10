/*
name: 004_Bronze_to_Silver_inline.sql
description: BRONZEの生データをクレンジング・加工してSILVERに書き込むストアドプロシージャ（inline版）
*/
-- セッション設定
USE ROLE SYSADMIN;
USE DATABASE TITANIC_DB;
USE SCHEMA TITANIC_DB.SILVER;
USE WAREHOUSE TITANIC_WH;

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
  HANDLER = 'main'
  EXECUTE AS CALLER
AS $$
import pandas as pd

def main(session):
    # BRONZEから読み込み
    df = session.table('TITANIC_DB.BRONZE.RAW_TITANIC').to_pandas()

    # 欠損値補完
    df['AGE']      = df['AGE'].fillna(df['AGE'].median())
    df['EMBARKED'] = df['EMBARKED'].fillna('S')

    # 性別エンコーディング
    df['SEX_ENCODED'] = df['SEX'].map({'male': 1, 'female': 0})

    # EMBARKEDのOne-hotエンコーディング
    embarked_dummies = pd.get_dummies(df['EMBARKED'], prefix='EMBARKED')
    for col in ['EMBARKED_C', 'EMBARKED_Q', 'EMBARKED_S']:
        if col not in embarked_dummies.columns:
            embarked_dummies[col] = 0

    # 必要カラムのみ抽出
    df_silver = pd.DataFrame({
        'PASSENGERID' : df['PASSENGERID'],
        'SURVIVED'    : df['SURVIVED'],
        'PCLASS'      : df['PCLASS'],
        'SEX_ENCODED' : df['SEX_ENCODED'],
        'AGE'         : df['AGE'],
        'SIBSP'       : df['SIBSP'],
        'PARCH'       : df['PARCH'],
        'FARE'        : df['FARE'],
        'EMBARKED_C'  : embarked_dummies['EMBARKED_C'].astype(int),
        'EMBARKED_Q'  : embarked_dummies['EMBARKED_Q'].astype(int),
        'EMBARKED_S'  : embarked_dummies['EMBARKED_S'].astype(int),
    })

    # SILVERに書き込み
    session.write_pandas(
        df_silver,
        'FEATURE_TITANIC',
        schema='SILVER',
        database='TITANIC_DB',
        overwrite=True
    )
    return f'完了: {len(df_silver)} 件をSILVERに書き込みました'
$$;

-- ストアドプロシージャの実行
CALL TITANIC_DB.SILVER.SP_BRONZE_TO_SILVER();

-- 確認
SELECT * FROM TITANIC_DB.SILVER.FEATURE_TITANIC LIMIT 10;
SELECT COUNT(*) AS ROW_COUNT FROM TITANIC_DB.SILVER.FEATURE_TITANIC;