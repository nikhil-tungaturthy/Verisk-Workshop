{{
    config(
        materialized='view',
        tags=['intermediate', 'gl']
    )
}}

/*
    Adds the Size of Loss (SOL) band column.

    SOL assignment rules (per GL Data Transformation Business Rules v2, §3.5):
        - claim_id is null         → sol = null (premium-only row)
        - tl_inc_indem < 0         → sol = null (NEGATIVE_INCURRED rows excluded)
        - tl_inc_indem = 0, i_alae > 0 → sol = '0' (special carve-out)
        - tl_inc_indem in [1, 5000] → sol = '1'
        - ... (see size_of_loss_bands seed for remaining buckets)

    The seed contains bands '1' through '11'. Band '0' is the carve-out and
    is intentionally NOT in the seed — it's handled in the CASE below.
*/

with claims as (

    select * from {{ ref('int_gl__claims_enriched') }}

),

with_sol as (

    select
        c.*,
        case
            when c.claim_id is null                                  then null
            when c.tl_inc_indem < 0                                  then null
            when c.tl_inc_indem = 0 and coalesce(c.i_alae, 0) > 0    then '0'
            else sol.band
        end                                                          as sol
    from claims c
    left join {{ ref('size_of_loss_bands') }} sol
        on c.claim_id is not null
       and c.tl_inc_indem > 0
       and c.tl_inc_indem between sol.band_min and coalesce(sol.band_max, 999999999999)

)

select * from with_sol
