-- BUSINESS ANALYTICS — Segmentation + airport dependency + scenario simulation
-- Source of truth: nyc_taxi_db.yellow_taxi_gold_table

-- Define airport zones from the findings (3 zones with 100% dependency in the data)
-- 132, 138, 70

CREATE OR REPLACE VIEW nyc_taxi_db.yellow_taxi_business AS
SELECT
    *,
    CASE
        WHEN pulocationid IN (132, 138, 70)
          OR dolocationid IN (132, 138, 70)
        THEN 1 ELSE 0
    END AS is_airport_trip,
    CASE
        WHEN AVG(total_amount) OVER (PARTITION BY pulocationid) > 40
         AND (STDDEV(total_amount) OVER (PARTITION BY pulocationid)
              / AVG(total_amount) OVER (PARTITION BY pulocationid)) < 0.5
        THEN 'PREMIUM_STABLE'
        ELSE 'VOLUME_VOLATILE'
    END AS business_segment
FROM nyc_taxi_db.yellow_taxi_gold_table;

-- Zone metrics + risk labeling
CREATE OR REPLACE VIEW nyc_taxi_db.yellow_taxi_zone_risk AS
WITH zone_metrics AS (
    SELECT
        pulocationid,
        COUNT(*) AS trips,
        AVG(total_amount) AS avg_fare,
        SUM(total_amount) AS total_revenue,
        SUM(CASE WHEN is_airport_trip = 1 THEN total_amount ELSE 0 END)
            / SUM(total_amount) AS airport_dependency_ratio
    FROM nyc_taxi_db.yellow_taxi_business
    GROUP BY pulocationid
)
SELECT
    pulocationid,
    trips,
    avg_fare,
    total_revenue,
    airport_dependency_ratio,
    CASE
        WHEN airport_dependency_ratio >= 0.8 THEN 'CRITICAL_RISK'
        WHEN airport_dependency_ratio BETWEEN 0.4 AND 0.8 THEN 'AT_RISK'
        ELSE 'SAFE'
    END AS zone_risk_level
FROM zone_metrics;

-- Executive summary
CREATE OR REPLACE VIEW nyc_taxi_db.yellow_taxi_executive_summary AS
SELECT
    zone_risk_level AS risk_category,
    COUNT(DISTINCT b.pulocationid) AS number_of_zones,
    COUNT(*) AS total_trips,
    CAST(ROUND(SUM(total_amount),2) AS DECIMAL(18,2)) AS total_revenue,
    CAST(ROUND(AVG(total_amount),2) AS DECIMAL(18,2)) AS avg_fare,
    CAST(
        ROUND(
            SUM(CASE WHEN is_airport_trip = 1 THEN total_amount ELSE 0 END) / SUM(total_amount),
            2
        ) AS DECIMAL(18,2)
    ) AS airport_dependency_ratio,
    CAST(
        ROUND(
            SUM(CASE WHEN is_airport_trip = 1 THEN total_amount * 0.5 ELSE total_amount END),
            2
        ) AS DECIMAL(18,2)
    ) AS revenue_after_50pct_airport_drop,
    CAST(
        ROUND(
            SUM(total_amount) - SUM(CASE WHEN is_airport_trip = 1 THEN total_amount * 0.5 ELSE total_amount END),
            2
        ) AS DECIMAL(18,2)
    ) AS potential_revenue_loss
FROM nyc_taxi_db.yellow_taxi_business b
JOIN nyc_taxi_db.yellow_taxi_zone_risk z
  ON b.pulocationid = z.pulocationid
GROUP BY zone_risk_level
ORDER BY potential_revenue_loss DESC;

-- Final output
SELECT * FROM nyc_taxi_db.yellow_taxi_executive_summary;
