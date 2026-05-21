{#
    Portfolio-level loss ratio sanity check.

    Warns when sum(tl_inc_indem) / sum(prem) falls outside [0.2, 2.0].

    A ratio outside this band is a data smell, not a hard transformation
    bug — it could be a real underwriting result, but it's worth surfacing.
    Severity is warn so it shows in the job report without failing the run.

    Returns rows when the ratio is out of bounds. Empty result = pass.
#}

{{ config(severity='warn') }}

with agg as (
    select
        sum(coalesce(prem, 0))                            as total_prem,
        sum(coalesce(cast(tl_inc_indem as number), 0))    as total_inc
    from {{ ref('fct_gl_transactions') }}
)

select
    total_prem,
    total_inc,
    total_inc / nullif(total_prem, 0) as loss_ratio
from agg
where total_prem > 0
  and (
        total_inc / nullif(total_prem, 0) < 0.2
     or total_inc / nullif(total_prem, 0) > 2.0
      )
