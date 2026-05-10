/*
name: 999_Cleanup.sql
description: ハンズオン環境をクリーンアップする
*/

-- 環境を削除できる管理者権限を使用
USE ROLE ACCOUNTADMIN;

-- ウェアハウスの削除
DROP WAREHOUSE IF EXISTS TITANIC_WH;

-- データベースの削除（スキーマ・テーブル・ステージ・FILE FORMATすべて含む）
DROP DATABASE IF EXISTS TITANIC_DB;