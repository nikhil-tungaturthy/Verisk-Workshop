{#
    normalize_asl(col)

    Normalize an ASL code by stripping the decimal point so all carriers'
    ASL columns share the same representation across the project.

    Examples:
        17.1  → '171'
        17.2  → '172'
        18.1  → '181'
        18.2  → '182'
        17.65 → '1765'  (non-GL, will be filtered later)

    Parameters:
        col — column reference (unquoted, e.g. asl)

    Returns:
        VARCHAR — the ASL with no decimal point. NULL passes through.
#}

{% macro normalize_asl(col) %}
    case
        when {{ col }} is null then null
        else replace(cast({{ col }} as varchar), '.', '')
    end
{% endmacro %}
