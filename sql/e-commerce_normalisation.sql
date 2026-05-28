-- ============================================================
-- FILE 3: e-commerce_normalisation.sql
-- Purpose : Transform raw tables into a star schema in ANALYTICS_DB
--           Demonstrates: Snowflake-native GENERATOR for date spine,
--           window functions for pageview ranking, business logic
--           embedding for traffic classification and funnel mapping
-- Author  : Tuan Thanh Thinh
-- Project : Maven Fuzzy Factory — E-Commerce Analytics
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE raw_warehouse;
USE DATABASE ANALYTICS_DB;
USE SCHEMA ANALYTICS_DB.STAR_SCHEMA;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- ------------------------------------------------------------
-- DIM_DATE
-- Uses Snowflake-native GENERATOR function to build a complete
-- date spine over a fixed range — no dependency on fact tables,
-- no expensive UNION scans, executes instantly.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.DIM_DATE AS
WITH date_spine AS (
    SELECT
        DATEADD(DAY, SEQ4(), '2012-01-01'::DATE) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))   -- generates 2000 candidate dates
    WHERE full_date <= '2016-12-31'::DATE     -- trim to project window
)
SELECT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD'))   AS date_key,       -- surrogate key (YYYYMMDD integer)
    full_date,
    YEAR(full_date)                              AS year,
    QUARTER(full_date)                           AS quarter,
    MONTH(full_date)                             AS month_number,
    MONTHNAME(full_date)                         AS month_name,
    DAY(full_date)                               AS day_number,
    DAYNAME(full_date)                           AS day_name,
    CASE DAYNAME(full_date)
        WHEN 'Mon' THEN 1
        WHEN 'Tue' THEN 2
        WHEN 'Wed' THEN 3
        WHEN 'Thu' THEN 4
        WHEN 'Fri' THEN 5
        WHEN 'Sat' THEN 6
        WHEN 'Sun' THEN 7
    END                                          AS day_sort_order,  -- enables correct weekday sorting
    IFF(DAYNAME(full_date) IN ('Sat','Sun'), TRUE, FALSE) AS is_weekend
FROM date_spine
ORDER BY full_date;

-- ------------------------------------------------------------
-- DIM_PRODUCT
-- Simple product lookup — no transformation needed
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.DIM_PRODUCT AS
SELECT
    product_id,
    product_name,
    created_at AS product_created_at
FROM RAW_DB.PUBLIC.PRODUCTS;

-- ============================================================
-- FACT TABLES
-- ============================================================

-- ------------------------------------------------------------
-- FACT_WEBSITE_SESSIONS
-- Embeds traffic source classification business logic directly
-- in SQL — classifies each session into a human-readable
-- traffic source type based on UTM parameters and referrer.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.FACT_WEBSITE_SESSIONS AS
SELECT
    website_session_id,
    user_id,
    TO_NUMBER(TO_CHAR(created_at::DATE, 'YYYYMMDD'))    AS session_date_key,
    created_at,
    created_at::DATE                                     AS session_date,
    HOUR(created_at)                                     AS session_hour,
    is_repeat_session,
    LOWER(device_type)                                   AS device_type,
    utm_source,
    utm_campaign,
    utm_content,
    http_referer,
    -- Traffic source classification (business logic embedded at source)
    CASE
        WHEN utm_source = 'gsearch'    AND utm_campaign IS NOT NULL THEN 'paid_gsearch'
        WHEN utm_source = 'bsearch'    AND utm_campaign IS NOT NULL THEN 'paid_bsearch'
        WHEN utm_source = 'socialbook'                              THEN 'paid_social'
        WHEN utm_source IS NULL        AND http_referer IS NOT NULL THEN 'organic_search'
        WHEN utm_source IS NULL        AND http_referer IS NULL     THEN 'direct'
        ELSE 'other'
    END                                                  AS traffic_source_type
FROM RAW_DB.PUBLIC.WEBSITE_SESSIONS;

-- ------------------------------------------------------------
-- FACT_PAGEVIEWS
-- Uses ROW_NUMBER() window function to rank pageviews within
-- each session — computed once at load time in Snowflake
-- instead of via expensive DAX calculated columns in Power BI.
-- This avoids O(N²) row-context loops in the VertiPaq engine.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.FACT_PAGEVIEWS AS
SELECT
    website_pageview_id,
    website_session_id,
    TO_NUMBER(TO_CHAR(created_at::DATE, 'YYYYMMDD'))    AS pageview_date_key,
    created_at                                           AS pageview_created_at,
    pageview_url,
    -- Funnel stage classification
    CASE
        WHEN pageview_url = '/home'               THEN 'home'
        WHEN pageview_url LIKE '%lander%'         THEN 'lander'
        WHEN pageview_url LIKE '%products%'       THEN 'product'
        WHEN pageview_url LIKE '%cart%'           THEN 'cart'
        WHEN pageview_url LIKE '%shipping%'       THEN 'shipping'
        WHEN pageview_url LIKE '%billing%'        THEN 'billing'
        WHEN pageview_url LIKE '%thank-you%'      THEN 'thank_you'
        ELSE 'other'
    END                                                  AS page_type,
    -- Window function: rank pageviews within each session by time
    ROW_NUMBER() OVER (
        PARTITION BY website_session_id
        ORDER BY created_at ASC
    )                                                    AS page_order,
    -- Derived flag: 1 if this is the first pageview of the session
    CASE
        WHEN ROW_NUMBER() OVER (
            PARTITION BY website_session_id
            ORDER BY created_at ASC
        ) = 1 THEN 1 ELSE 0
    END                                                  AS is_first_pageview
FROM RAW_DB.PUBLIC.WEBSITE_PAGEVIEWS;

-- ------------------------------------------------------------
-- FACT_ORDERS
-- Includes profit calculation pushed down to SQL layer
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.FACT_ORDERS AS
SELECT
    order_id,
    website_session_id,
    user_id,
    TO_NUMBER(TO_CHAR(created_at::DATE, 'YYYYMMDD'))    AS order_date_key,
    created_at                                           AS order_created_at,
    primary_product_id,
    items_purchased,
    price_usd                                            AS order_revenue_usd,
    cogs_usd                                             AS order_cogs_usd,
    price_usd - cogs_usd                                 AS order_profit_usd
FROM RAW_DB.PUBLIC.ORDERS;

-- ------------------------------------------------------------
-- FACT_ORDER_ITEMS
-- Line-item level orders with profit margin per item
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.FACT_ORDER_ITEMS AS
SELECT
    order_item_id,
    order_id,
    product_id,
    TO_NUMBER(TO_CHAR(created_at::DATE, 'YYYYMMDD'))    AS order_item_date_key,
    created_at                                           AS order_item_created_at,
    is_primary_item,
    price_usd                                            AS item_revenue_usd,
    cogs_usd                                             AS item_cogs_usd,
    price_usd - cogs_usd                                 AS item_profit_usd
FROM RAW_DB.PUBLIC.ORDER_ITEMS;

-- ------------------------------------------------------------
-- FACT_REFUNDS
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ANALYTICS_DB.STAR_SCHEMA.FACT_REFUNDS AS
SELECT
    order_item_refund_id,
    order_item_id,
    order_id,
    TO_NUMBER(TO_CHAR(created_at::DATE, 'YYYYMMDD'))    AS refund_date_key,
    created_at                                           AS refund_created_at,
    refund_amount_usd
FROM RAW_DB.PUBLIC.ORDER_ITEM_REFUNDS;

-- ============================================================
-- VALIDATION QUERIES
-- Run after all tables are created to confirm correctness
-- ============================================================

-- Row counts across all star schema tables
SELECT 'DIM_DATE'               AS table_name, COUNT(*) AS row_count FROM ANALYTICS_DB.STAR_SCHEMA.DIM_DATE
UNION ALL
SELECT 'DIM_PRODUCT',                          COUNT(*) FROM ANALYTICS_DB.STAR_SCHEMA.DIM_PRODUCT
UNION ALL
SELECT 'FACT_WEBSITE_SESSIONS',                COUNT(*) FROM ANALYTICS_DB.STAR_SCHEMA.FACT_WEBSITE_SESSIONS
UNION ALL
SELECT 'FACT_PAGEVIEWS',                       COUNT(*) FROM ANALYTICS_DB.STAR_SCHEMA.FACT_PAGEVIEWS
UNION ALL
SELECT 'FACT_ORDERS',                          COUNT(*) FROM ANALYTICS_DB.STAR_SCHEMA.FACT_ORDERS
UNION ALL
SELECT 'FACT_ORDER_ITEMS',                     COUNT(*) FROM ANALYTICS_DB.STAR_SCHEMA.FACT_ORDER_ITEMS
UNION ALL
SELECT 'FACT_REFUNDS',                         COUNT(*) FROM ANALYTICS_DB.STAR_SCHEMA.FACT_REFUNDS
ORDER BY table_name;

-- Verify traffic source classification distribution
SELECT
    traffic_source_type,
    COUNT(*)                                            AS session_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)  AS pct_of_total
FROM ANALYTICS_DB.STAR_SCHEMA.FACT_WEBSITE_SESSIONS
GROUP BY traffic_source_type
ORDER BY session_count DESC;

-- Verify page_order and is_first_pageview are correctly computed
SELECT
    website_session_id,
    pageview_url,
    page_order,
    is_first_pageview
FROM ANALYTICS_DB.STAR_SCHEMA.FACT_PAGEVIEWS
WHERE website_session_id IN (
    SELECT DISTINCT website_session_id
    FROM ANALYTICS_DB.STAR_SCHEMA.FACT_PAGEVIEWS
    LIMIT 3
)
ORDER BY website_session_id, page_order;

-- Verify DIM_DATE covers full project date range
SELECT
    MIN(full_date) AS date_from,
    MAX(full_date) AS date_to,
    COUNT(*)       AS total_days
FROM ANALYTICS_DB.STAR_SCHEMA.DIM_DATE;

-- Verify conversion rate at SQL level (sanity check vs Power BI)
SELECT
    COUNT(DISTINCT s.website_session_id)                            AS total_sessions,
    COUNT(DISTINCT o.order_id)                                      AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0
        / COUNT(DISTINCT s.website_session_id), 2)                  AS conversion_rate_pct
FROM ANALYTICS_DB.STAR_SCHEMA.FACT_WEBSITE_SESSIONS s
LEFT JOIN ANALYTICS_DB.STAR_SCHEMA.FACT_ORDERS o
    ON s.website_session_id = o.website_session_id;


