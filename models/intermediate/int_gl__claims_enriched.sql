{{
    config(
        materialized='view',
        tags=['intermediate', 'gl']
    )
}}

/*
    Claim-level metric calculations. All loss columns populate ONLY where
    claim_id is not null; premium-only rows keep nulls in these fields.

    Formulas:
        tl_paid_indem  = round(pd_indem, 0)
        tl_inc_indem   = round(pd_indem + case_rsv - recovery_amt, 0)
        p_alae         = round(p_alae_raw, 0)
        i_alae         = round(i_alae_raw, 0)
        i_occs         = 1 (one occurrence per claim row, per pattern A)
        p_occs         = 1 when pd_indem > 0, else null
        claim_status   = OPEN/CLSD/REOP → O/C/R (via claim_status_codes seed)
        status_date    = rpt_date (proxy — flagged via STATUS_DATE_PROXY in qc layer)

    Notes:
        - ULAE columns are always null (not present in Carrier_B source)
        - SOL is computed in the next model (int_gl__claims_with_sol) because
          it depends on tl_inc_indem which is computed here.
*/

with base as (

    select * from {{ ref('int_gl__policies_enriched') }}

),

claims as (

    select
        b.*,

        -----------------------------------------------------------------------
        -- Loss metrics (claim rows only; null on premium-only)
        -----------------------------------------------------------------------
        case
            when b.claim_id is not null
            then cast(round(coalesce(b.pd_indem, 0), 0) as integer)
        end                                                                as tl_paid_indem,

        case
            when b.claim_id is not null
            then cast(round(
                coalesce(b.pd_indem,     0)
              + coalesce(b.case_rsv,     0)
              - coalesce(b.recovery_amt, 0),
                0
            ) as integer)
        end                                                                as tl_inc_indem,

        case
            when b.claim_id is not null
            then cast(round(coalesce(b.p_alae_raw, 0), 0) as integer)
        end                                                                as p_alae,

        case
            when b.claim_id is not null
            then cast(round(coalesce(b.i_alae_raw, 0), 0) as integer)
        end                                                                as i_alae,

        cast(null as integer)                                              as tl_paid_ulae,
        cast(null as integer)                                              as tl_inc_ulae,

        -----------------------------------------------------------------------
        -- Claim status & status date
        -----------------------------------------------------------------------
        csc.status_code                                                    as claim_status,
        case when b.claim_id is not null then b.rpt_date end               as status_date,

        -----------------------------------------------------------------------
        -- Occurrence counts
        -----------------------------------------------------------------------
        case when b.claim_id is not null then 1 end                        as i_occs,
        case
            when b.claim_id is not null and coalesce(b.pd_indem, 0) > 0
            then 1
        end                                                                as p_occs

    from base b
    left join {{ ref('claim_status_codes') }} csc
        on b.clm_status_raw = csc.raw_status

)

select * from claims
