-- 01_clean.sql
-- Load the raw Kaggle export, run data-quality checks, and build a clean table.
-- Note: the original CSV uses old-Mac CR line endings; it was converted to LF
-- (tr '\r' '\n') before loading. See README.

CREATE OR REPLACE TABLE raw AS
SELECT * FROM read_csv_auto('data/KAG_conversion_data.csv');

-- ---------------------------------------------------------------
-- Data-quality checks (each should be reviewed before analysis)
-- ---------------------------------------------------------------

-- 1. Row count and key uniqueness  -> 1,143 rows, 1,143 unique ad_ids
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT ad_id) AS n_unique_ads FROM raw;

-- 2. Nulls in any column  -> 0
SELECT
    COUNT(*) FILTER (WHERE ad_id IS NULL OR xyz_campaign_id IS NULL OR age IS NULL
                     OR gender IS NULL OR interest IS NULL OR Impressions IS NULL
                     OR Clicks IS NULL OR Spent IS NULL OR Total_Conversion IS NULL
                     OR Approved_Conversion IS NULL) AS rows_with_nulls
FROM raw;

-- 3. Exact duplicate rows (ignoring ad_id)  -> 1 pair; kept, because each ad_id is a distinct ad
SELECT COUNT(*) AS duplicate_groups
FROM (SELECT * EXCLUDE (ad_id) FROM raw GROUP BY ALL HAVING COUNT(*) > 1);

-- 4. Logical consistency
SELECT
    COUNT(*) FILTER (WHERE Clicks > Impressions)                  AS clicks_gt_impr,       -- 0
    COUNT(*) FILTER (WHERE Approved_Conversion > Total_Conversion) AS approved_gt_total,   -- 0
    COUNT(*) FILTER (WHERE Spent = 0)                              AS zero_spend_ads,      -- 207
    COUNT(*) FILTER (WHERE Spent = 0 AND Total_Conversion > 0)     AS zero_spend_with_conv -- conversions not driven by paid clicks
FROM raw;

-- 5. No date column exists in this dataset, so there are no date formats to fix
--    and no day-of-week segmentation is possible (documented as a limitation).

-- ---------------------------------------------------------------
-- Clean table: readable names, typed columns, campaign labels
-- ---------------------------------------------------------------
CREATE OR REPLACE TABLE ads AS
SELECT
    ad_id,
    'Campaign ' || CASE xyz_campaign_id WHEN 916 THEN 'A' WHEN 936 THEN 'B' WHEN 1178 THEN 'C' END
                                        AS campaign,
    xyz_campaign_id,
    fb_campaign_id,
    age                                 AS age_group,
    CASE gender WHEN 'M' THEN 'Male' WHEN 'F' THEN 'Female' END AS gender,
    interest                            AS interest_id,
    Impressions                         AS impressions,
    Clicks                              AS clicks,
    ROUND(Spent, 2)                     AS spend,
    Total_Conversion                    AS leads,      -- enquired about the product
    Approved_Conversion                 AS sales,      -- bought the product
    (Spent = 0)                         AS is_unpaid   -- delivered impressions but no paid clicks
FROM raw;
