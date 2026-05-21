{{
    config(
        materialized='table',
        tags=['marts', 'gl'],
        cluster_by=['carrier_code', 'submission_id', 'year']
    )
}}

/*
    Canonical Verisk-format GL transaction fact.

    One row per source row (policy row, optionally with claim columns
    populated). Column order follows the Verisk output schema spec from
    notebook 04 / GL Data Transformation Business Rules v2 Section 1.

    To extend to multiple carriers, replace the int_gl__qc_flags ref with
    a UNION across per-carrier intermediate models (see int_gl__filtered_transactions
    for the recommended dbt_utils.union_relations pattern).
*/

select
    -- Tracking
    carrier_code,
    submission_id,
    eval_date,

    -- Identifiers
    policy_id,
    location_id,
    claim_id,
    claimant_id,

    -- Policy-level
    policy_eff_date,
    policy_exp_date,
    policy_size_band,

    -- Dimensions
    state              as st,
    sub,
    terr,
    zip_cd,
    mcg,
    class_cd           as class,
    year,
    qtr,
    acc_year,
    acc_qtr,
    rep_year,
    rep_qtr,
    top,
    cov,
    exp_ind,
    exp_base,

    -- Loss characterization
    tol,
    sol,
    claim_status,
    status_date,

    -- Metrics
    wprem,
    prem,
    expo,
    wexpo,
    tl_paid_indem,
    tl_inc_indem,
    p_alae,
    i_alae,
    tl_paid_ulae,
    tl_inc_ulae,
    p_occs,
    i_occs,

    -- Quality
    qc_flag

from {{ ref('int_gl__qc_flags') }}
