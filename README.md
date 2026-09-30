# NYC Taxi Lakehouse on AWS (S3 + Athena)

End-to-end lakehouse-style analytics project using NYC Yellow Taxi parquet data on AWS S3, queried and modeled in Amazon Athena using a Bronze/Silver/Gold architecture.

## Stack
- AWS S3 (data lake storage)
- Amazon Athena (SQL engine + CTAS into Parquet)
- AWS Glue Data Catalog (metadata)
- Parquet + Snappy compression

## Architecture (Medallion)
- **Bronze (raw):** S3 `raw/nyc_taxi/yellow/` + Athena external table
- **Silver (curated):** CTAS Parquet outputs in S3 `silver/nyc_taxi/yellow/`
- **Gold (analytics ready):** cleaned & partitioned CTAS table in S3 `gold/nyc_taxi/yellow/`
- **Semantic/Executive layer:** views for segmentation + airport dependency risk + scenario simulation

## How to run (in order)
1. Run `sql/01_bronze_raw.sql`
2. Run `sql/02_silver_curated.sql`
3. Run `sql/03_gold_table.sql`
4. Run `sql/04_business_analytics.sql`

## Key outputs
- Cleaned Gold dataset partitioned by `pickup_date`
- Business segmentation by pickup zone (premium vs volume)
- Airport dependency ratio by zone
- “What-if” scenario: 50% airport traffic drop → revenue impact
- Board-level executive summary view

## Local regression check

Run `python3 -m unittest discover -s tests -v` with Python 3.11 or later.
The test executes the executive-summary aggregation over synthetic joined tables
using the standard-library SQLite engine. It checks distinct zone counts, trip
counts, revenue, and the airport-drop scenario. Only `CREATE OR REPLACE VIEW`
is adapted to SQLite's `CREATE VIEW` syntax. This is a local SQL logic check,
not validation of Athena deployment, CTAS, or S3 access.
