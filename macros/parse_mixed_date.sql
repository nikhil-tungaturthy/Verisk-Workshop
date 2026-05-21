{#
    parse_mixed_date(col)

    Parse a VARCHAR column containing dates in any of four observed formats:
        MM/DD/YYYY        e.g. '04/28/2024'
        MM-DD-YYYY        e.g. '10-12-2023'
        YYYY-MM-DD        e.g. '2022-09-26'
        YYYYMMDD          e.g. '20240203'

    Returns a DATE. Returns NULL if no format matches (so downstream tests
    catch parse failures as not_null violations).

    Snowflake-specific: relies on TRY_TO_DATE returning NULL on failure.
    For BigQuery use SAFE.PARSE_DATE; for Postgres use a CASE on length
    plus TO_DATE inside a savepoint. Override this macro per adapter.

    Parameters:
        col — column reference (unquoted, e.g. eff_dt)

    Returns:
        DATE — parsed date, or NULL if input does not match any known format.
#}

{% macro parse_mixed_date(col) %}
    coalesce(
        try_to_date({{ col }}, 'MM/DD/YYYY'),
        try_to_date({{ col }}, 'MM-DD-YYYY'),
        try_to_date({{ col }}, 'YYYY-MM-DD'),
        try_to_date({{ col }}, 'YYYYMMDD')
    )
{% endmacro %}
