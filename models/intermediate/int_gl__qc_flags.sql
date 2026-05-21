{{
    config(
        materialized='view',
        tags=['intermediate', 'gl']
    )
}}

/*
    Build the semicolon-delimited QC_FLAG column.

    Flag definitions (preserved in the order applied by the pandas notebook
    so the resulting strings match byte-for-byte):

        MISSING_STATE          state is null
        MISSING_YEAR           year is null
        MISSING_CLASS          prem > 0 and class_cd is null
        EARNED_GT_WRITTEN      prem > wprem * 1.001 (1.001 tolerance for round-trip)
        NEGATIVE_INCURRED      claim row with tl_inc_indem < 0
        LOSS_BEFORE_INCEPTION  occurrence-trigger claim with acc_date < eff_date
        CLAIM_BEFORE_INCEPTION claims-made claim with rpt_date < eff_date
        STATUS_DATE_PROXY      every claim row (records that status_date is proxied
                               from rpt_date — see int_gl__claims_enriched)
        LOSS_ON_ZERO_PREM      claim row on a policy with wprem = 0

    Output is null when no flags fire (clean row).
*/

with base as (

    select * from {{ ref('int_gl__claims_with_sol') }}

),

flagged as (

    select
        *,
        nullif(
            trim(
                case when state    is null then 'MISSING_STATE;'    else '' end ||
                case when year     is null then 'MISSING_YEAR;'     else '' end ||
                case
                    when prem > 0 and class_cd is null
                    then 'MISSING_CLASS;' else ''
                end ||
                case
                    when prem > wprem * 1.001
                    then 'EARNED_GT_WRITTEN;' else ''
                end ||
                case
                    when claim_id is not null and tl_inc_indem < 0
                    then 'NEGATIVE_INCURRED;' else ''
                end ||
                case
                    when cov = 'OCC'
                     and acc_date is not null
                     and acc_date < policy_eff_date
                    then 'LOSS_BEFORE_INCEPTION;' else ''
                end ||
                case
                    when cov = 'CM'
                     and rpt_date is not null
                     and rpt_date < policy_eff_date
                    then 'CLAIM_BEFORE_INCEPTION;' else ''
                end ||
                case
                    when claim_id is not null
                    then 'STATUS_DATE_PROXY;' else ''
                end ||
                case
                    when claim_id is not null and coalesce(wprem, 0) = 0
                    then 'LOSS_ON_ZERO_PREM;' else ''
                end,
                ';'
            ),
            ''
        )                                                                  as qc_flag
    from base

)

select * from flagged
