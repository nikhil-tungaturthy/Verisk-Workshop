{{
    config(
        materialized='table',
        tags=['marts', 'semantic_layer']
    )
}}

with days as (
    {{
        dbt.date_spine(
            'day',
            "to_date('2000-01-01')",
            "dateadd(day, 31, current_date())"
        )
    }}
),

final as (
    select cast(date_day as date) as date_day
    from days
)

select *
from final
where date_day >= dateadd(year, -10, current_date())
