{{ header }}
CREATE OR REPLACE VIEW
  `{{ project_id }}.{{ dataset }}.{{ name }}`
AS
WITH active_users AS (
  SELECT
    submission_date,
    client_id,
    sample_id,
    first_seen_date,
    app_name,
    normalized_channel,
    locale,
    country,
    isp,
    app_display_version,
    is_dau,
    is_wau,
    is_mau,
    is_mobile,
  FROM
    `{{ project_id }}.{{ dataset }}.active_users`
)
{% if attribution_fields %},
  attribution AS (
    SELECT
      client_id,
      sample_id,
      channel AS normalized_channel,
      {% for field in attribution_fields %}
        {% if app_name == "fenix" and field.name == "adjust_campaign" %}
          CASE
            WHEN adjust_network IN ('Google Organic Search', 'Organic')
              THEN 'Organic'
            ELSE NULLIF(adjust_campaign, "")
          END AS adjust_campaign,
        {% elif field.type == "STRING" %}
          NULLIF({{ field.name }}, "") AS {{ field.name }},
        {% else %}
          {{ field.name }},
        {% endif %}
      {% endfor %}
    FROM
      {% if app_name == "fenix" %}
        `{{ project_id }}.{{ dataset }}_derived.firefox_android_clients_v1`
      {% elif app_name == "firefox_ios" %}
        `{{ project_id }}.{{ dataset }}_derived.firefox_ios_clients_v1`
      {% endif %}
  )
{% endif %}
SELECT
  submission_date,
  client_id,
  sample_id,
  first_seen_date,
  app_name,
  normalized_channel,
  app_display_version AS app_version,
  locale,
  country,
  isp,
  is_dau,
  is_wau,
  is_mau,
  is_mobile,
  {% for field in attribution_fields %}
    attribution.{{ field.name }},
  {% endfor %}
  {% for field in attribution_fields if field.name == "adjust_network" %}
    `moz-fx-data-shared-prod.udf.organic_vs_paid_mobile`(attribution.adjust_network) AS paid_vs_organic,
  {% else %}
    "Organic" AS paid_vs_organic,
  {% endfor %}
  CASE
    WHEN active_users.submission_date = first_seen_date
      THEN 'new_profile'
    WHEN DATE_DIFF(active_users.submission_date, first_seen_date, DAY)
      BETWEEN 1
      AND 27
      THEN 'repeat_user'
    WHEN DATE_DIFF(active_users.submission_date, first_seen_date, DAY) >= 28
      THEN 'existing_user'
    ELSE 'Unknown'
  END AS lifecycle_stage,
FROM
  active_users
  {% if attribution_fields %}
    LEFT JOIN
      attribution
      USING (client_id, sample_id, normalized_channel)
  {% endif %}
