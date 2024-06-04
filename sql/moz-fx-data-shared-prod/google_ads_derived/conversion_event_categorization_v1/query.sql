--STEP 1: Get clients with a first seen date = submission date - 14 days
--Note: Min cohort date is 2023-11-01 so backfilling will return nothing before then
--Note: Max cohort date cannot be more than 7 days ago (to ensure we always have at least 7 days of data)
WITH clients_first_seen_14_days_ago AS (
  SELECT
    client_id,
    first_seen_date,
    country,
    attribution_campaign,
    attribution_content,
    attribution_dltoken,
    attribution_medium,
    attribution_source
  FROM
    `moz-fx-data-shared-prod.telemetry.clients_first_seen` --contains all new clients, including those that never sent a main ping
  WHERE
    first_seen_date = @report_date --this is 14 days before {{ds}}
    AND first_seen_date
    BETWEEN '2023-11-01'
    AND DATE_SUB(CURRENT_DATE, INTERVAL 8 DAY)
),
--Step 2: Get only the columns we need from clients last seen, for only the small window of time we need
clients_last_seen_raw AS (
  SELECT
    cls.client_id,
    cls.first_seen_date,
    cls.country,
    cls.submission_date,
    cls.days_since_seen,
    cls.active_hours_sum,
    cls.days_visited_1_uri_bits,
    cls.days_interacted_bits,
    cls.search_with_ads_count_all
  FROM
    `moz-fx-data-shared-prod.telemetry.clients_last_seen` cls
  JOIN
    clients_first_seen_14_days_ago clients
    ON cls.client_id = clients.client_id
  WHERE
    cls.submission_date >= '2023-11-01' --first cohort date
    AND cls.submission_date
    BETWEEN cls.first_seen_date
    AND DATE_ADD(cls.first_seen_date, INTERVAL 6 DAY) --get first 7 days from their first main ping
    --to process less data, we only check for pings between @submission date - 15 days and submission date + 15 days for each date this runs
    AND cls.submission_date
    BETWEEN DATE_SUB(@report_date, INTERVAL 1 DAY) --15 days before DS
    AND DATE_ADD(@report_date, INTERVAL 29 DAY) --15 days after DS
),
--STEP 2: For every client, get the first 7 days worth of main pings sent after their first main ping
client_activity_first_7_days AS (
  SELECT
    client_id,
    ANY_VALUE(
      first_seen_date
    ) AS first_seen_date, --date we got first main ping (potentially different than above first seen date)
    ANY_VALUE(
      CASE
        WHEN first_seen_date = submission_date
          THEN country
      END
    ) AS country, --any country from their first day in clients_last_seen
    ANY_VALUE(
      CASE
        WHEN submission_date = DATE_ADD(first_seen_date, INTERVAL 6 DAY)
          THEN BIT_COUNT(days_visited_1_uri_bits & days_interacted_bits)
      END
    ) AS dou, --total # of days of activity during their first 7 days of main pings
  -- if a client doesn't send a ping on `submission_date` their last active day's value will be carried forward
  -- so we only take measurements from days that they send a ping.
    SUM(
      CASE
        WHEN days_since_seen = 0
          THEN COALESCE(active_hours_sum, 0)
        ELSE 0
      END
    ) AS active_hours_sum,
    SUM(
      CASE
        WHEN days_since_seen = 0
          THEN COALESCE(search_with_ads_count_all, 0)
        ELSE 0
      END
    ) AS search_with_ads_count_all
  FROM
    clients_last_seen_raw
  GROUP BY
    client_id
),
combined AS (
  SELECT
    cfs.client_id,
    cfs.first_seen_date,
    cfs.attribution_campaign,
    cfs.attribution_content,
    cfs.attribution_dltoken,
    cfs.attribution_medium,
    cfs.attribution_source,
    IF(cls.first_seen_date IS NOT NULL, TRUE, FALSE) AS sent_main_ping_in_first_7_days,
    COALESCE(
      cls.country,
      cfs.country
    ) AS country, -- Conversion events & LTV are based on their first observed country in CLS, use that country if its available
    COALESCE(dou, 0) AS dou,
    COALESCE(active_hours_sum, 0) AS active_hours_sum,
    COALESCE(search_with_ads_count_all, 0) AS search_with_ads_count_all
  FROM
    clients_first_seen_14_days_ago AS cfs
  LEFT JOIN
    client_activity_first_7_days AS cls
    USING (client_id)
)
SELECT
  client_id,
  first_seen_date,
  attribution_campaign,
  attribution_content,
  attribution_dltoken,
  attribution_medium,
  attribution_source,
  @submission_date AS report_date,
  sent_main_ping_in_first_7_days,
  country,
  dou,
  active_hours_sum,
  search_with_ads_count_all,
  IF(search_with_ads_count_all > 0 AND dou >= 5, TRUE, FALSE) AS event_1,
  IF(search_with_ads_count_all > 0 AND dou >= 3, TRUE, FALSE) AS event_2,
  IF(active_hours_sum >= 0.4 AND dou >= 3, TRUE, FALSE) AS event_3,
FROM
  combined
