{{ header }}
CREATE OR REPLACE VIEW
  `{{ project_id }}.{{ dataset }}.{{ name }}`
AS
SELECT
  *,
  CASE
    WHEN first_seen_date = metric_date
      THEN 'new_profile'
    WHEN DATE_DIFF(metric_date, first_seen_date, DAY)
      BETWEEN 1
      AND 27
      THEN 'repeat_user'
    WHEN DATE_DIFF(metric_date, first_seen_date, DAY) >= 28
      THEN 'existing_user'
    ELSE 'Unknown'
  END AS lifecycle_stage,
  {% for field in attribution_fields if field.name == "adjust_network" %}
    `moz-fx-data-shared-prod.udf.organic_vs_paid_mobile`(adjust_network) AS paid_vs_organic,
  {% else %}
    "Organic" AS paid_vs_organic,
  {% endfor %}
FROM
  `{{ project_id }}.{{ dataset }}_derived.{{ name }}_{{ version }}`
