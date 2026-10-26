-- 02_metrics.sql
-- Core funnel and efficiency metrics, overall and by segment.
-- Run after 01_clean.sql.
--
-- Definitions
--   CTR             = clicks / impressions
--   Lead CVR        = leads (Total_Conversion) / clicks
--   Approval rate   = sales (Approved_Conversion) / leads
--   CPL             = spend / leads
--   CPA             = spend / sales            <- primary efficiency metric
--   ROAS            = (sales * assumed sale value) / spend
--
-- ASSUMPTION: the dataset has no revenue column. ROAS uses an assumed
-- $100 of revenue per approved sale. Change it here; every query picks it up.
-- Break-even sale value for any segment = its CPA.
SET VARIABLE sale_value = 100;

-- ---------------------------------------------------------------
-- Overall
-- ---------------------------------------------------------------
SELECT
    COUNT(*)                                             AS ads,
    ROUND(SUM(spend), 2)                                 AS spend,
    SUM(impressions)                                     AS impressions,
    SUM(clicks)                                          AS clicks,
    SUM(leads)                                           AS leads,
    SUM(sales)                                           AS sales,
    ROUND(100.0 * SUM(clicks) / SUM(impressions), 4)     AS ctr_pct,
    ROUND(100.0 * SUM(leads)  / SUM(clicks), 2)          AS lead_cvr_pct,
    ROUND(100.0 * SUM(sales)  / SUM(leads), 1)           AS approval_rate_pct,
    ROUND(SUM(spend) / SUM(leads), 2)                    AS cpl,
    ROUND(SUM(spend) / SUM(sales), 2)                    AS cpa,
    ROUND(SUM(sales) * getvariable('sale_value') / SUM(spend), 2) AS roas
FROM ads;

-- ---------------------------------------------------------------
-- Segment view: one row per segment value, all metrics + spend share.
-- Built as a long table so every segmentation uses the same formulas.
-- ---------------------------------------------------------------
CREATE OR REPLACE TABLE segment_metrics AS
WITH long AS (
    SELECT 'campaign'  AS dimension, campaign             AS segment, * FROM ads
    UNION ALL
    SELECT 'age_group',              age_group,                       * FROM ads
    UNION ALL
    SELECT 'gender',                 gender,                          * FROM ads
    UNION ALL
    SELECT 'interest',               CAST(interest_id AS VARCHAR),    * FROM ads
)
SELECT
    dimension,
    segment,
    COUNT(*)                                                         AS ads,
    ROUND(SUM(spend), 2)                                             AS spend,
    ROUND(100.0 * SUM(spend) / SUM(SUM(spend)) OVER (PARTITION BY dimension), 1) AS spend_share_pct,
    ROUND(100.0 * SUM(sales) / SUM(SUM(sales)) OVER (PARTITION BY dimension), 1) AS sales_share_pct,
    SUM(impressions)                                                 AS impressions,
    SUM(clicks)                                                      AS clicks,
    SUM(leads)                                                       AS leads,
    SUM(sales)                                                       AS sales,
    ROUND(100.0 * SUM(clicks) / SUM(impressions), 4)                 AS ctr_pct,
    ROUND(100.0 * SUM(leads)  / NULLIF(SUM(clicks), 0), 2)           AS lead_cvr_pct,
    ROUND(100.0 * SUM(sales)  / NULLIF(SUM(leads), 0), 1)            AS approval_rate_pct,
    ROUND(SUM(spend) / NULLIF(SUM(leads), 0), 2)                     AS cpl,
    ROUND(SUM(spend) / NULLIF(SUM(sales), 0), 2)                     AS cpa,
    ROUND(SUM(sales) * getvariable('sale_value') / NULLIF(SUM(spend), 0), 2) AS roas
FROM long
GROUP BY dimension, segment;

SELECT * FROM segment_metrics WHERE dimension <> 'interest' ORDER BY dimension, segment;
