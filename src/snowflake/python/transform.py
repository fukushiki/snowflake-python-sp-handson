"""
transform.py
------------
Snowflake Stored Procedure ハンドラーモジュール。
BRONZE層の生データをクレンジング・特徴量エンジニアリングしてSILVER層に書き込む。

Snowflakeストアドプロシージャから import で参照され、
HANDLER = 'transform.main' として呼び出される。
"""
import pandas as pd
from snowflake.snowpark import Session


def main(session: Session) -> str:
    """
    BRONZE.RAW_TITANIC を読み込み、加工してSILVER.FEATURE_TITANICに書き込む。

    Parameters
    ----------
    session : snowflake.snowpark.Session
        Snowflakeストアドプロシージャが自動的に注入するSnowparkセッション。
        テーブルの読み書きやSQLの実行に使用する。
        明示的に生成・クローズする必要はない。

    Returns
    -------
    str
        処理完了メッセージ（書き込み件数を含む）。
        Snowflakeのストアドプロシージャ実行結果として表示される。
    """
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