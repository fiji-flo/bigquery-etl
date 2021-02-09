CREATE TABLE IF NOT EXISTS
  `moz-fx-data-shared-prod.telemetry_derived.experiment_enrollment_aggregates_hourly_v1`(
    timestamp TIMESTAMP,
    `type` STRING,
    branch STRING,
    experiment STRING,
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    enroll_count INT64,
    unenroll_count INT64,
    graduate_count INT64,
    update_count INT64,
    enroll_failed_count INT64,
    unenroll_failed_count INT64,
    update_failed_count INT64,
    disqualification_count INT64,
    exposure_count INT64
  )
PARTITION BY
  TIMESTAMP_TRUNC(timestamp, HOUR)
CLUSTER BY
  experiment
