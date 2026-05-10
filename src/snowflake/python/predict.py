"""
predict.py
----------
Snowflake Stored Procedure ハンドラーモジュール。
SILVER層の特徴量データを使ってMLモデルを学習・予測し、GOLD層に書き込む。

Snowflakeストアドプロシージャから import で参照され、
HANDLER = 'predict.main' として呼び出される。
"""
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
from snowflake.snowpark import Session


def main(session: Session) -> str:
    """
    SILVER.FEATURE_TITANIC を読み込み、モデルを学習・予測してGOLD.PREDICTION_TITANICに書き込む。

    Parameters
    ----------
    session : snowflake.snowpark.Session
        Snowflakeストアドプロシージャが自動的に注入するSnowparkセッション。
        テーブルの読み書きやSQLの実行に使用する。
        明示的に生成・クローズする必要はない。

    Returns
    -------
    str
        処理完了メッセージ（精度と書き込み件数を含む）。
        Snowflakeのストアドプロシージャ実行結果として表示される。
    """
    # SILVERから読み込み
    df = session.table('TITANIC_DB.SILVER.FEATURE_TITANIC').to_pandas()

    # 特徴量とターゲットの分離
    features = [
        'PCLASS', 'SEX_ENCODED', 'AGE', 'SIBSP',
        'PARCH', 'FARE', 'EMBARKED_C', 'EMBARKED_Q', 'EMBARKED_S'
    ]
    X = df[features]
    y = df['SURVIVED']

    # 学習・テスト分割
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # モデル学習
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    # 全データに対して予測
    y_pred = model.predict(X)
    y_prob = model.predict_proba(X)[:, 1]

    # GOLD テーブル用 DataFrame
    df_gold = pd.DataFrame({
        'PASSENGERID'        : df['PASSENGERID'],
        'SURVIVED_ACTUAL'    : df['SURVIVED'],
        'SURVIVED_PREDICTED' : y_pred,
        'SURVIVAL_PROB'      : y_prob,
        'IS_CORRECT'         : (df['SURVIVED'].values == y_pred),
    })

    # GOLDに書き込み
    session.write_pandas(
        df_gold,
        'PREDICTION_TITANIC',
        schema='GOLD',
        database='TITANIC_DB',
        overwrite=True
    )

    acc = accuracy_score(y, y_pred)
    return f'完了: 精度={acc:.2%}, {len(df_gold)} 件をGOLDに書き込みました'