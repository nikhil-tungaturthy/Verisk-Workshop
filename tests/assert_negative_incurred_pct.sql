{#
    Negative incurred ratio check.

    Warns when the share of claim rows with negative tl_inc_indem exceeds
    5% of all claim rows. Some negatives are normal (recoveries exceeding
    paid + case_reserve on a closed claim), but a high rate signals
    upstream booking errors or reserve adjustments.

    Severity is warn — the NEGATIVE_INCURRED flag in qc_flag also surfaces
    these row-by-row.

    Returns one row with the ratio when the threshold is exceeded.
    Empty result = pass.
#}

{{ config(severity='warn') }}

with claim_rows as (
    select
        count(case when cast(tl_inc_indem as number) < 0 then 1 end) as neg_count,
        count(*)                                                     as total_claims
    from {{ ref('fct_gl_transactions') }}
    where claim_id is not null
)

select
    neg_count,
    total_claims,
    (neg_count::float / nullif(total_claims, 0)) * 100 as neg_pct
from claim_rows
where total_claims > 0
  and (neg_count::float / nullif(total_claims, 0)) > 0.05
