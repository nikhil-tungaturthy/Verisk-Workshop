{#
    Premium reconciliation test.

    Asserts that sum(wprem) in the GL-filtered intermediate model equals
    sum(wprem) in the final mart, within a 0.1% tolerance.

    This catches accidental row drops/duplicates between the GL filter and
    the final SELECT. The failure is hard (severity=error) because a
    reconciliation break in this layer always indicates a transformation
    bug, never a data quality issue.

    Returns rows when reconciliation fails. Empty result = pass.
#}

{{ config(severity='error') }}

with src as (
    select sum(coalesce(wprem, 0)) as src_wprem
    from {{ ref('int_gl__filtered_transactions') }}
),

mart as (
    select sum(coalesce(wprem, 0)) as mart_wprem
    from {{ ref('fct_gl_transactions') }}
)

select
    'WPREM_RECONCILIATION_FAILED'                                       as failure_reason,
    src.src_wprem,
    mart.mart_wprem,
    abs(src.src_wprem - mart.mart_wprem) / nullif(src.src_wprem, 0)     as diff_pct
from src
cross join mart
where abs(src.src_wprem - mart.mart_wprem) / nullif(src.src_wprem, 0) >= 0.001
