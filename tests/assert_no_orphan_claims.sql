{#
    Orphan claims check.

    Warns on claim rows booked against policies with zero written premium.
    These are real data quality issues (claim amounts on a zero-premium
    policy distort downstream loss ratios) but they reflect upstream
    carrier reporting, not a transformation bug.

    Severity is warn — the LOSS_ON_ZERO_PREM flag in qc_flag also surfaces
    these row-by-row.

    Returns one row per orphan claim. Empty result = pass.
#}

{{ config(severity='warn') }}

select
    policy_id,
    claim_id,
    wprem,
    tl_inc_indem
from {{ ref('fct_gl_transactions') }}
where claim_id is not null
  and coalesce(wprem, 0) = 0
