-- ============================================================
-- FILE 1: e-commerce_setup.sql
-- Purpose : One-time environment setup — warehouse, databases,
--           schemas, file formats, and staging area
-- Author  : Tuan Thanh Thinh
-- Project : Maven Fuzzy Factory — E-Commerce Analytics
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- 1. COMPUTE WAREHOUSE
-- ============================================================
CREATE OR REPLACE WAREHOUSE raw_warehouse
    WAREHOUSE_SIZE   = 'X-SMALL'
    AUTO_SUSPEND     = 60          -- suspends after 60s idle (cost control)
    AUTO_RESUME      = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Compute warehouse for Maven Fuzzy Factory e-commerce project';

USE WAREHOUSE raw_warehouse;

-- ============================================================
-- 2. DATABASES  (two-layer architecture)
-- ============================================================
-- Layer 1: raw, unmodified source data as loaded from CSV
CREATE DATABASE IF NOT EXISTS RAW_DB
    COMMENT = 'Layer 1 — raw unmodified data as loaded from source files';

-- Layer 2: star schema, analytics-ready for Power BI consumption
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB
    COMMENT = 'Layer 2 — star schema modelled for Power BI reporting';

-- ============================================================
-- 3. SCHEMAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS RAW_DB.PUBLIC
    COMMENT = 'Raw source tables — no transformations applied';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.STAR_SCHEMA
    COMMENT = 'Star schema: fact and dimension tables for Power BI';

SHOW SCHEMAS IN DATABASE RAW_DB;
SHOW SCHEMAS IN DATABASE ANALYTICS_DB;

-- ============================================================
-- 4. FILE FORMATS
-- Two formats are required because the CSV files have different
-- line endings depending on the OS they were exported from.
-- ============================================================

-- Format A: Windows line endings (CRLF)
-- Applies to: orders, order_items, order_item_refunds,
--             products, website_sessions
CREATE OR REPLACE FILE FORMAT RAW_DB.PUBLIC.CSV_CRLF
    TYPE                     = 'CSV'
    FIELD_DELIMITER          = ','
    RECORD_DELIMITER         = '\r\n'
    SKIP_HEADER              = 1
    NULL_IF                  = ('NULL', 'null', 'N/A', '', 'NaN')
    EMPTY_FIELD_AS_NULL      = TRUE
    TRIM_SPACE               = TRUE
    COMMENT = 'CSV format for Windows-exported files (CRLF line endings)';

-- Format B: Unix line endings (LF) with quoted fields
-- Applies to: website_pageviews only
CREATE OR REPLACE FILE FORMAT RAW_DB.PUBLIC.CSV_LF
    TYPE                        = 'CSV'
    FIELD_DELIMITER             = ','
    RECORD_DELIMITER            = '\n'
    SKIP_HEADER                 = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF                     = ('NULL', 'null', 'N/A', '', 'NaN')
    EMPTY_FIELD_AS_NULL         = TRUE
    TRIM_SPACE                  = TRUE
    COMMENT = 'CSV format for Unix-exported files with quoted fields (LF line endings)';

-- ============================================================
-- 5. STAGING AREA
-- A single internal stage to hold all 6 source CSV files
-- ============================================================
CREATE STAGE IF NOT EXISTS RAW_DB.PUBLIC.STG_RAW
    COMMENT = 'Internal stage — upload all 6 source CSV files here before ingestion';

-- Verify stage contents after uploading files via Snowsight UI
SHOW STAGES IN SCHEMA RAW_DB.PUBLIC;
LIST @RAW_DB.PUBLIC.STG_RAW;
