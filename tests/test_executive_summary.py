"""Check summary aggregation locally; this is not an Athena integration test."""
import sqlite3
import unittest
from pathlib import Path


class ExecutiveSummaryTest(unittest.TestCase):
    def test_joined_zone_summary_counts_zones_and_revenue(self):
        sql = (Path(__file__).resolve().parents[1] / "sql/04_business_analytics.sql").read_text()
        start = sql.index("CREATE OR REPLACE VIEW nyc_taxi_db.yellow_taxi_executive_summary")
        summary = sql[start:sql.index(";", start)]
        # SQLite supports the aggregation here, but uses CREATE VIEW syntax.
        summary = summary.replace("CREATE OR REPLACE VIEW", "CREATE VIEW")
        with sqlite3.connect(":memory:") as db:
            db.execute("ATTACH DATABASE ':memory:' AS nyc_taxi_db")
            db.executescript("""
                CREATE TABLE nyc_taxi_db.yellow_taxi_business (
                    pulocationid INTEGER, total_amount REAL, is_airport_trip INTEGER
                );
                CREATE TABLE nyc_taxi_db.yellow_taxi_zone_risk (
                    pulocationid INTEGER, zone_risk_level TEXT
                );
                INSERT INTO nyc_taxi_db.yellow_taxi_business VALUES
                    (132, 100.0, 1), (132, 60.0, 1), (138, 40.0, 1), (1, 20.0, 0);
                INSERT INTO nyc_taxi_db.yellow_taxi_zone_risk VALUES
                    (132, 'CRITICAL_RISK'), (138, 'CRITICAL_RISK'), (1, 'SAFE');
            """)
            db.execute(summary)
            rows = db.execute(
                "SELECT * FROM nyc_taxi_db.yellow_taxi_executive_summary "
                "ORDER BY potential_revenue_loss DESC"
            ).fetchall()
        self.assertEqual(rows, [
            ('CRITICAL_RISK', 2, 3, 200.0, 66.67, 1.0, 100.0, 100.0),
            ('SAFE', 1, 1, 20.0, 20.0, 0.0, 20.0, 0.0),
        ])


if __name__ == "__main__":
    unittest.main()
