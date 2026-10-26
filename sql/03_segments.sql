-- 03_segments.sql
-- Cross-segment cuts used for the three insights. Run after 02_metrics.sql.

-- A. Campaign x age: does the age pattern hold inside each campaign?
SELECT
    campaign, age_group,
    ROUND(SUM(spend), 2)                                    AS spend,
    ROUND(100.0 * SUM(clicks) / SUM(impressions), 4)        AS ctr_pct,
    SUM(sales)                                              AS sales,
    ROUND(SUM(spend) / NULLIF(SUM(sales), 0), 2)            AS cpa
FROM ads
GROUP BY campaign, age_group
ORDER BY campaign, age_group;

-- B. Campaign x gender
SELECT
    campaign, gender,
    ROUND(SUM(spend), 2)                                    AS spend,
    ROUND(100.0 * SUM(spend) / SUM(SUM(spend)) OVER (PARTITION BY campaign), 1) AS pct_of_campaign_spend,
    ROUND(100.0 * SUM(clicks) / SUM(impressions), 4)        AS ctr_pct,
    SUM(sales)                                              AS sales,
    ROUND(SUM(spend) / NULLIF(SUM(sales), 0), 2)            AS cpa
FROM ads
GROUP BY campaign, gender
ORDER BY campaign, gender;

-- C. Campaign C: age x gender CPA grid (95% of spend lives here)
CREATE OR REPLACE TABLE c_age_gender AS
SELECT
    gender, age_group,
    ROUND(SUM(spend), 2)                                    AS spend,
    ROUND(100.0 * SUM(spend) / (SELECT SUM(spend) FROM ads), 1) AS pct_of_total_spend,
    SUM(sales)                                              AS sales,
    ROUND(SUM(spend) / NULLIF(SUM(sales), 0), 2)            AS cpa
FROM ads
WHERE campaign = 'Campaign C'
GROUP BY gender, age_group
ORDER BY gender, age_group;
SELECT * FROM c_age_gender;

-- D. Reallocation scenario: move $5,000 from age 45-49 to age 30-34.
--    Uses average CPA as a stand-in for marginal CPA, so treat as an upper bound;
--    real marginal CPA rises as a segment scales. Validate with a holdout test.
WITH cpa AS (
    SELECT age_group, SUM(spend) / SUM(sales) AS cpa FROM ads GROUP BY age_group
)
SELECT
    ROUND(5000 / (SELECT cpa FROM cpa WHERE age_group = '45-49'), 0) AS sales_lost,
    ROUND(5000 / (SELECT cpa FROM cpa WHERE age_group = '30-34'), 0) AS sales_gained,
    ROUND(5000 / (SELECT cpa FROM cpa WHERE age_group = '30-34')
        - 5000 / (SELECT cpa FROM cpa WHERE age_group = '45-49'), 0) AS net_sales_upper_bound;

-- E. Paid vs unpaid rows: 207 ads have $0 spend yet report conversions
--    (likely view-through / organic attribution). They're kept in totals, flagged here.
SELECT is_unpaid, COUNT(*) AS ads, SUM(leads) AS leads, SUM(sales) AS sales
FROM ads GROUP BY is_unpaid;
