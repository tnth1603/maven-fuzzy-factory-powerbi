# Maven Fuzzy Factory — E-Commerce Traffic & Funnel Analytics Dashboard

![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)
![Data Analysis](https://img.shields.io/badge/Data%20Analysis-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=for-the-badge)

---

## Table of Contents

1. [Introduction](#introduction)
2. [Problem Statement](#problem-statement)
3. [Skills Demonstrated](#skills-demonstrated)
4. [Data Sourcing](#data-sourcing)
5. [Data Transformation](#data-transformation)
6. [Modelling](#modelling)
7. [Analysis & Visualisation](#analysis--visualisation)
8. [Conclusion & Recommendations](#conclusion--recommendations)

---

## Introduction

Maven Fuzzy Factory is a fictional e-commerce company used as a learning dataset by Maven Analytics. This project presents an end-to-end **business intelligence dashboard** built in Power BI, designed to give stakeholders a clear, interactive view of website traffic performance and customer conversion behaviour across the period **March 2012 – April 2015**.

The dashboard is structured across four report pages — **Traffic Overview**, **Traffic Analytics**, **Funnel Overview**, and **Funnel Analytics** — enabling both high-level monitoring and deep-dive analysis of how users discover, engage with, and convert through the Maven Fuzzy Factory website.

---

## Problem Statement

Maven Fuzzy Factory's marketing and product teams need a centralised reporting solution to answer key questions about their website traffic and sales funnel. Without a unified view, it is difficult to identify which channels drive quality traffic, where customers drop off in the purchase journey, and how performance trends over time.

### Business Questions to Solve

**Traffic Performance**
- How have total sessions, new sessions, and repeat sessions trended over time?
- What proportion of total traffic comes from mobile vs. desktop devices?
- Which traffic sources (paid search, organic, direct, paid social) are driving the most sessions?
- How does paid search as a share of total traffic change month over month and year over year?

**Traffic Quality & Engagement**
- Which traffic source delivers the highest session engagement rate and average time on site?
- How do new session rates differ across traffic sources — which channels attract mostly first-time visitors vs. returning users?
- How is traffic distributed across months of the year, and are there seasonal patterns by source?

**Conversion & Funnel Performance**
- What is the overall website conversion rate, and how has it changed over time?
- How do conversion rates differ between desktop and mobile users?
- At which stage of the funnel (Product Page → Cart → Shipping → Billing → Converted) do the most sessions drop off?
- Which traffic sources have the highest and lowest funnel completion rates?
- Which entry landing pages convert best, and which have the highest bounce rates?

**Behavioural Patterns**
- What time of day sees the highest volume of sessions, and does conversion rate vary by hour period?
- Which day of the week drives the most sessions and the highest conversion rate?
- How many page views do converted users view compared to non-converted users?
- How do conversion rates break down by the combination of traffic source and device type?

---

## Skills Demonstrated

- **Data modelling** — star schema design with fact and dimension tables in Power BI
- **DAX (Data Analysis Expressions)** — calculated columns, measures, KPIs including MoM % change, PY comparisons, conversion rates, bounce rates, and engagement metrics
- **Power Query (M Language)** — data cleaning, transformation, and table joins
- **Data visualisation design** — multi-page interactive report with consistent branding, slicers, cross-filtering, and drill-through capability
- **UX & report layout** — intuitive navigation with a sidebar menu, date range pickers, and conditional formatting
- **Business intelligence storytelling** — translating raw transactional data into actionable marketing and funnel insights

---

## Data Sourcing

- **Source:** [Maven Analytics – E-Commerce Dataset](https://app.mavenanalytics.io/datasets?search=e-commerce)
- **Format:** CSV files
- **Coverage:** March 2012 – April 2015

### Tables Included

| Table | Rows | Description |
|---|---|---|
| `orders` | 32,313 | Order-level records with revenue and COGS |
| `order_items` | 40,025 | Line items per order including product and price |
| `order_item_refunds` | 1,731 | Refund records linked to order items |
| `products` | 4 | Product dimension with names and creation dates |
| `website_sessions` | — | Session-level data with traffic source, device type, UTM parameters |
| `website_pageviews` | — | Pageview-level data per session |

---

## Data Transformation

All transformations were performed in **Power Query** within Power BI before loading into the data model. Key steps included:

- **Data type standardisation** — ensuring date, integer, and decimal types were correctly assigned across all tables
- **Null handling** — addressing missing UTM fields (campaign, source, content) for direct and organic traffic sessions
- **Derived columns** — extracting `SESSION_DATE`, `Session Hour`, and `hour_period` from raw datetime fields
- **Traffic source classification** — creating a clean `Traffic Source Type` label by combining UTM source and medium fields into human-readable categories (e.g. `paid_gsearch`, `organic_search`, `direct`, `paid_social`)
- **Session type flag** — deriving `IS_REPEAT_SESSION` to distinguish new vs. returning visitors
- **Funnel stage mapping** — joining pageview URL data to a `FunnelStages` reference table to assign each pageview a stage label and step order
- **Date dimension** — building a `DIM_DATE` table with full calendar attributes (day name, month number, quarter, year, `YearMonthDate`) to support time intelligence calculations
- **Hour dimension** — building a `DIM_HOUR` table with `hour`, `hour_num`, and `hour_period` for intraday analysis

---

## Modelling

The data model follows a **star schema** design, with fact tables at the centre connected to supporting dimension tables via defined relationships.

### Fact Tables
- `FACT_WEBSITE_SESSIONS` — one row per session with traffic source, device, and user attributes
- `FACT_PAGEVIEWS` — one row per pageview linked to sessions
- `FACT_ORDERS` — one row per order with revenue, COGS, and product info
- `FACT_ORDER_ITEMS` — one row per order line item
- `FACT_REFUNDS` — one row per refund transaction

### Dimension Tables
- `DIM_DATE` — full date dimension for time intelligence
- `DIM_HOUR` — intraday hour groupings
- `DIM_PRODUCT` — product lookup table
- `Session_Legend` — maps `IS_REPEAT_SESSION` flag to `Session_Type` label
- `FunnelStages` — defines ordered funnel stages and URL filters
- `LanderStages` — maps landing page URLs to display labels
- `Day_Sort` / `Hour_Sort` — sort-order tables for correct day and hour sequencing in visuals

### Key Relationships
- Sessions → Date (many-to-one on `SESSION_DATE`)
- Sessions → Hour (many-to-one on `hour_period`)
- Pageviews → Sessions (many-to-one on `WEBSITE_SESSION_ID`)
- Orders → Sessions (many-to-one on `WEBSITE_SESSION_ID`)
- Order Items → Orders (many-to-one on `ORDER_ID`)
- Order Items → Products (many-to-one on `PRODUCT_ID`)
- Refunds → Order Items (many-to-one on `ORDER_ITEM_ID`)

---

## Analysis & Visualisation

The report is structured across **four pages**, each targeting a specific area of business performance.

---

### Page 1 — Traffic Overview

**Purpose:** High-level summary of website session volume and traffic composition over time.

**Key Metrics (KPI Cards):**
- Total Sessions, New Sessions, Repeat Sessions — each with Prior Year (PY) and Month-over-Month (MoM) comparisons
- Mobile Sessions, Paid Search %, Total Users

**Visuals:**
- **Donut chart** — Total Sessions split by device type (Desktop vs. Mobile)
- **Line chart** — Total Sessions by Month and Traffic Source Type, showing channel growth trends from 2012 to 2015
- **Stacked bar chart** — Total Sessions by Month and Session Type (New vs. Repeat)
- **Bar chart** — Total Sessions by Traffic Source (absolute volume comparison)

**Filters:** Date range pickers, Traffic Source slicer, Campaign slicer

---

### Page 2 — Traffic Analytics

**Purpose:** Deep-dive into traffic quality and engagement by source.

**Key Metrics (KPI Cards):** Same top-row KPIs as Traffic Overview for consistent context.

**Visuals:**
- **Summary table** — Traffic Source Type × Total Sessions, Engaged Sessions, Engagement Rate, Avg Time per Session, Event per Session (with conditional formatting on Engaged Sessions)
- **Horizontal bar chart** — New Session Breakdown by Traffic Source (% of sessions that are new visitors)
- **Heat map / matrix** — Traffic Source Distribution Across Months (session counts by source × month number)

---

### Page 3 — Funnel Overview

**Purpose:** Understand how sessions progress through the purchase funnel and where drop-off occurs.

**Key Metrics (KPI Cards):**
- Overall Conversion Rate, Bounce Rate — with PY and MoM comparisons
- Desktop CVR, Mobile CVR

**Visuals:**
- **Funnel bar chart** — Funnel Sessions Dynamic by Stage Label (Entry → Product Page → Cart → Shipping → Billing → Converted), showing absolute session counts and an overall 6.8% conversion rate
- **Line chart** — Conversion Rate over Time by device type (Desktop vs. Mobile), indexed by month
- **Horizontal bar chart** — Conversion Rate by Traffic Source Type
- **Horizontal bar chart** — Bounce Rate by Traffic Source Type
- **Horizontal bar chart** — Conversion Rate by Entry Page (Home, Lander 1–5)

---

### Page 4 — Funnel Analytics

**Purpose:** Granular analysis of conversion behaviour by time, day, traffic source, and device.

**Key Metrics (KPI Cards):** Conversion Rate, Bounce Rate, Desktop CVR, Mobile CVR (consistent with Funnel Overview).

**Visuals:**
- **Combo chart** — Conversion Rate by Hour Period (Early Morning, Morning, Afternoon, Evening, Night, Late Night) with session volume as bars and CVR as a line
- **Funnel completion table** — Stage-by-stage drop-off rates (%) broken down by Traffic Source Type
- **Day-of-week table** — Day × New Session %, Total Sessions, Conversion Rate
- **Clustered bar chart** — Avg Page Views: Converted vs. Non-Converted users
- **Matrix** — Traffic Source × Device Type Conversion Rate cross-tab

---

## Conclusion & Recommendations

### Key Findings

- **Paid Google Search dominates traffic** — accounting for 316K of 473K total sessions (~67%), making it the most critical channel to optimise and protect.
- **Mobile is a significant and growing segment** — representing 146K sessions (31% of total), yet Mobile CVR (3.09%) is substantially lower than Desktop CVR (8.50%), signalling a user experience gap.
- **Paid Social has the lowest conversion rate** (3.21%) and highest bounce rate (77.63%), suggesting sessions from this source are largely unqualified or the landing experience is poorly matched to intent.
- **Organic search delivers the highest conversion rate** (7.51%) and one of the highest engagement rates (60.77%), indicating strong purchase intent among these visitors.
- **The biggest funnel drop-off occurs between Entry and Product Page** — only 55% of sessions reach the product page — presenting the largest single opportunity to improve top-of-funnel engagement.
- **Lander 5 outperforms all other landing pages** with a 10.17% conversion rate, compared to just 3.39% for Lander 3, suggesting that landing page content and design have a material impact on downstream conversion.
- **Afternoon is the peak traffic period**, while conversion rate remains relatively stable across most hour periods (~6.8–6.9%), indicating time-of-day targeting adjustments may have limited impact.

### Recommendations

1. **Improve mobile experience** — prioritise mobile UX optimisation across the product page, cart, and checkout flow to close the desktop-mobile CVR gap.
2. **Reduce paid social spend or refine targeting** — the high bounce rate and low CVR from paid social suggests either audience misalignment or a weak landing page match; test dedicated social landing pages before scaling spend.
3. **Scale what works from organic search** — analyse the content, keywords, and landing pages driving organic conversions and replicate those patterns in paid campaigns.
4. **A/B test product page entry experience** — given the steep drop from Entry to Product Page, test above-the-fold content, page load speed, and calls to action.
5. **Replicate Lander 5's design across other entry pages** — with the highest CVR (10.17%), Lander 5's layout and messaging should inform the redesign of lower-performing landers.
6. **Monitor repeat session growth** — as repeat sessions grow from nearly zero in 2012 to a meaningful share by 2015, invest in retention-focused campaigns and personalisation to further improve lifetime value.

---

*Dashboard built with Power BI Desktop | Data sourced from [Maven Analytics](https://app.mavenanalytics.io/datasets?search=e-commerce)*
