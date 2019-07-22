-- Query generated by: templates/unnest_parquet_view.sql.py events_v1 telemetry_raw.events_v1
CREATE OR REPLACE VIEW
  `moz-fx-data-derived-datasets.telemetry.events_v1` AS
SELECT
  submission_date AS submission_date_s3,
  * REPLACE (
    event_map_values.key_value AS event_map_values,
    experiments.key_value AS experiments
  )
FROM
  `moz-fx-data-derived-datasets.telemetry_raw.events_v1`
