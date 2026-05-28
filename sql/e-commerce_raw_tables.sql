-- ============================================================
-- FILE 2: e-commerce_raw_tables.sql
-- Purpose : Create raw tables, load CSV data via COPY INTO,
--           and run data quality checks before transformation
-- Author  : Tuan Thanh Thinh
-- Project : Maven Fuzzy Factory — E-Commerce Analytics
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE raw_warehouse;
USE DATABASE RAW_DB;
USE SCHEMA RAW_DB.PUBLIC;

-- ============================================================
-- 1. CREATE RAW TABLES
-- Exact mirror of source CSV structure — no transformations
-- ============================================================

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.ORDERS (
    order_id            INTEGER,
    created_at          TIMESTAMP_NTZ,
    website_session_id  INTEGER,
    user_id             INTEGER,
    primary_product_id  INTEGER,
    items_purchased     INTEGER,
    price_usd           NUMBER(10,2),
    cogs_usd            NUMBER(10,2)
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.ORDER_ITEMS (
    order_item_id   INTEGER,
    created_at      TIMESTAMP_NTZ,
    order_id        INTEGER,
    product_id      INTEGER,
    is_primary_item INTEGER,
    price_usd       NUMBER(10,2),
    cogs_usd        NUMBER(10,2)
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.ORDER_ITEM_REFUNDS (
    order_item_refund_id    INTEGER,
    created_at              TIMESTAMP_NTZ,
    order_item_id           INTEGER,
    order_id                INTEGER,
    refund_amount_usd       NUMBER(10,2)
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.PRODUCTS (
    product_id   INTEGER,
    created_at   TIMESTAMP_NTZ,
    product_name STRING
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.WEBSITE_SESSIONS (
    website_session_id  INTEGER,
    created_at          TIMESTAMP_NTZ,
    user_id             INTEGER,
    is_repeat_session   INTEGER,
    utm_source          STRING,
    utm_campaign        STRING,
    utm_content         STRING,
    device_type         STRING,
    http_referer        STRING
);

CREATE OR REPLACE TABLE RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS (
    website_pageview_id INTEGER,
    created_at          TIMESTAMP_NTZ,
    website_session_id  INTEGER,
    pageview_url        STRING
);

-- ============================================================
-- 2. LOAD DATA VIA COPY INTO
-- Upload all 6 CSV files to @STG_RAW via Snowsight UI first
-- ============================================================

COPY INTO RAW_DB.PUBLIC.ORDERS
FROM @RAW_DB.PUBLIC.STG_RAW/orders.csv
FILE_FORMAT = RAW_DB.PUBLIC.CSV_CRLF
FORCE = TRUE;

COPY INTO RAW_DB.PUBLIC.ORDER_ITEMS
FROM @RAW_DB.PUBLIC.STG_RAW/order_items.csv
FILE_FORMAT = RAW_DB.PUBLIC.CSV_CRLF
FORCE = TRUE;

COPY INTO RAW_DB.PUBLIC.ORDER_ITEM_REFUNDS
FROM @RAW_DB.PUBLIC.STG_RAW/order_item_refunds.csv
FILE_FORMAT = RAW_DB.PUBLIC.CSV_CRLF
FORCE = TRUE;

COPY INTO RAW_DB.PUBLIC.PRODUCTS
FROM @RAW_DB.PUBLIC.STG_RAW/products.csv
FILE_FORMAT = RAW_DB.PUBLIC.CSV_CRLF
FORCE = TRUE;

COPY INTO RAW_DB.PUBLIC.WEBSITE_SESSIONS
FROM @RAW_DB.PUBLIC.STG_RAW/website_sessions.csv
FILE_FORMAT = RAW_DB.PUBLIC.CSV_CRLF
FORCE = TRUE;

COPY INTO RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS
FROM @RAW_DB.PUBLIC.STG_RAW/website_pageviews.csv
FILE_FORMAT = RAW_DB.PUBLIC.CSV_LF
FORCE = TRUE;
-- ============================================================
-- 3. DATA QUALITY CHECKS
-- Run these after loading to validate data before transformation
-- ============================================================

-- 3a. Row counts — verify all rows loaded correctly
SELECT 'ORDERS'              AS table_name, COUNT(*) AS row_count FROM RAW_DB.PUBLIC.ORDERS
UNION ALL
SELECT 'ORDER_ITEMS',                        COUNT(*) FROM RAW_DB.PUBLIC.ORDER_ITEMS
UNION ALL
SELECT 'ORDER_ITEM_REFUNDS',                 COUNT(*) FROM RAW_DB.PUBLIC.ORDER_ITEM_REFUNDS
UNION ALL
SELECT 'PRODUCTS',                           COUNT(*) FROM RAW_DB.PUBLIC.PRODUCTS
UNION ALL
SELECT 'WEBSITE_SESSIONS',                   COUNT(*) FROM RAW_DB.PUBLIC.WEBSITE_SESSIONS
UNION ALL
SELECT 'WEBSITE_PAGEVIEWS',                  COUNT(*) FROM RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS
ORDER BY table_name;

-- 3b. Duplicate checks — all primary keys should be unique
SELECT 'ORDERS — duplicate order_id' AS check_name, COUNT(*) AS duplicates
FROM (
    SELECT order_id FROM RAW_DB.PUBLIC.ORDERS
    GROUP BY order_id HAVING COUNT(*) > 1
)
UNION ALL
SELECT 'ORDER_ITEMS — duplicate order_item_id', COUNT(*)
FROM (
    SELECT order_item_id FROM RAW_DB.PUBLIC.ORDER_ITEMS
    GROUP BY order_item_id HAVING COUNT(*) > 1
)
UNION ALL
SELECT 'WEBSITE_SESSIONS — duplicate session_id', COUNT(*)
FROM (
    SELECT website_session_id FROM RAW_DB.PUBLIC.WEBSITE_SESSIONS
    GROUP BY website_session_id HAVING COUNT(*) > 1
)
UNION ALL
SELECT 'WEBSITE_PAGEVIEWS — duplicate pageview_id', COUNT(*)
FROM (
    SELECT website_pageview_id FROM RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS
    GROUP BY website_pageview_id HAVING COUNT(*) > 1
);
-- Expected: all duplicates = 0

-- 3c. Null checks — critical foreign keys must not be null
SELECT 'ORDERS — null order_id'                  AS check_name, COUNT(*) AS null_count FROM RAW_DB.PUBLIC.ORDERS             WHERE order_id IS NULL
UNION ALL
SELECT 'ORDER_ITEMS — null order_id',              COUNT(*) FROM RAW_DB.PUBLIC.ORDER_ITEMS          WHERE order_id IS NULL
UNION ALL
SELECT 'ORDER_ITEM_REFUNDS — null order_item_id',  COUNT(*) FROM RAW_DB.PUBLIC.ORDER_ITEM_REFUNDS   WHERE order_item_id IS NULL
UNION ALL
SELECT 'WEBSITE_SESSIONS — null session_id',       COUNT(*) FROM RAW_DB.PUBLIC.WEBSITE_SESSIONS     WHERE website_session_id IS NULL
UNION ALL
SELECT 'WEBSITE_PAGEVIEWS — null pageview_id',     COUNT(*) FROM RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS    WHERE website_pageview_id IS NULL;
-- Expected: all null_count = 0

-- 3d. Expected nulls — UTM fields are null for organic/direct traffic (normal)
SELECT
    COUNT(*)                                                        AS total_sessions,
    COUNT(utm_campaign)                                             AS sessions_with_campaign,
    total_sessions - sessions_with_campaign                        AS sessions_without_campaign,
    ROUND((sessions_without_campaign / total_sessions) * 100, 2)  AS pct_no_campaign
FROM RAW_DB.PUBLIC.WEBSITE_SESSIONS;

-- 3e. Date range check — confirm data covers expected period
SELECT
    MIN(created_at) AS earliest_date,
    MAX(created_at) AS latest_date,
    DATEDIFF('month', MIN(created_at), MAX(created_at)) AS months_covered
FROM RAW_DB.PUBLIC.ORDERS;

-- 3f. Sample data preview
SELECT * FROM RAW_DB.PUBLIC.ORDERS              LIMIT 5;
SELECT * FROM RAW_DB.PUBLIC.ORDER_ITEMS         LIMIT 5;
SELECT * FROM RAW_DB.PUBLIC.ORDER_ITEM_REFUNDS  LIMIT 5;
SELECT * FROM RAW_DB.PUBLIC.PRODUCTS            LIMIT 5;
SELECT * FROM RAW_DB.PUBLIC.WEBSITE_SESSIONS    LIMIT 5;
SELECT * FROM RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS   LIMIT 5;
