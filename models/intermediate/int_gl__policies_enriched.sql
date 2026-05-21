{{
    config(
        materialized='view',
        tags=['intermediate', 'gl']
    )
}}

/*
    Dimensional enrichment + pro-rata earned premium.

    Joins:
        - asl_to_subline      seed → subline (GL-PO or GL-PC)
        - asl_to_coverage     seed → coverage trigger (OCC or CM)
        - policy_size_bands   seed → policy size band (by written premium)

    Derives:
        - terr                  : first 3 chars of zip_cd
        - year, qtr             : from policy_eff_date
        - acc_year, acc_qtr     : from acc_date (null on premium-only rows)
        - rep_year, rep_qtr     : from rpt_date (null on premium-only rows)
        - prem                  : pro-rata earned premium (macro)

    Sets to null (columns kept for output schema compatibility):
        - mcg, exp_base, expo, wexpo

    Sets to false (no exposure data in source):
        - exp_ind
*/

with base as (

    select * from {{ ref('int_gl__filtered_transactions') }}

),

enriched as (

    select
        -- Tracking & identifiers (passthrough)
        b.carrier_code,
        b.submission_id,
        b.eval_date,
        b.policy_id,
        b.location_id,
        b.claim_id,
        b.claimant_id,

        -- Policy dates (passthrough)
        b.policy_eff_date,
        b.policy_exp_date,

        -- Geography (passthrough + derived TERR)
        b.state,
        b.zip_cd,
        case when b.zip_cd is not null then substring(b.zip_cd, 1, 3) end as terr,

        -- Codes (passthrough + null mcg)
        b.asl_normalized,
        b.class_cd,
        cast(null as varchar)                                              as mcg,
        sub.subline                                                        as sub,
        cov.coverage_trigger                                               as cov,

        -- Time dimensions
        date_part('year',    b.policy_eff_date)::integer                   as year,
        date_part('quarter', b.policy_eff_date)::integer                   as qtr,
        date_part('year',    b.acc_date)::integer                          as acc_year,
        case
            when b.acc_date is not null
            then date_part('quarter', b.acc_date)::integer
        end                                                                as acc_qtr,
        date_part('year',    b.rpt_date)::integer                          as rep_year,
        case
            when b.rpt_date is not null
            then date_part('quarter', b.rpt_date)::integer
        end                                                                as rep_qtr,

        -- Policy categoricals (passthrough)
        b.top,
        b.clm_status_raw,
        b.tol,

        -- Exposure fields (source has none; defaults set per business rules)
        false                                                              as exp_ind,
        cast(null as varchar)                                              as exp_base,
        cast(null as number)                                               as expo,
        cast(null as number)                                               as wexpo,

        -- Premium
        b.wprem,
        {{ pro_rata_earned_premium(
            'b.wprem',
            'b.policy_eff_date',
            'b.policy_exp_date',
            'b.eval_date'
        ) }}                                                               as prem,

        -- Policy size band (from seed)
        psb.band                                                           as policy_size_band,

        -- Loss raw columns (passthrough; rounding happens in claims layer)
        b.pd_indem,
        b.case_rsv,
        b.recovery_amt,
        b.p_alae_raw,
        b.i_alae_raw,
        b.acc_date,
        b.rpt_date

    from base b
    left join {{ ref('asl_to_subline')    }} sub on b.asl_normalized = sub.asl_normalized
    left join {{ ref('asl_to_coverage')   }} cov on b.asl_normalized = cov.asl_normalized
    left join {{ ref('policy_size_bands') }} psb
        on b.wprem between psb.band_min and coalesce(psb.band_max, 999999999)

)

select * from enriched
