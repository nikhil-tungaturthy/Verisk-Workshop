{{
    config(
        materialized='view',
        tags=['staging', 'carrier_b']
    )
}}

{#
    Carrier_B raw → standardized column names and types.

    This version refs synthetic_carrier_b as a seed for local testing.
    To wire up a real source table, swap the ref() call below to:
        {{ source('carrier_b_raw', 'synthetic_carrier_b') }}
    and restore _carrier_b__sources.yml.

    nullif(col, 'NULL') wrappers handle the literal "NULL" string in the
    seed CSV. Against a real warehouse table they are harmless no-ops.
#}

with src as (

    select * from {{ ref('synthetic_carrier_b') }}

),

renamed as (

    select
        -- Tracking
        '{{ var("carrier_code") }}'                                       as carrier_code,
        '{{ var("carrier_code") }}_'
            || replace('{{ var("eval_date") }}', '-', '')                 as submission_id,
        cast('{{ var("eval_date") }}' as date)                            as eval_date,

        -- Identifiers
        cast(pol_nbr as varchar)                                          as policy_id,
        nullif(claim_nbr, 'NULL')                                         as claim_id,
        cast(null as varchar)                                             as location_id,
        cast(null as varchar)                                             as claimant_id,

        -- Geography (PII omitted: insrd_name / insrd_addr_1 / insrd_city)
        case
            when upper(trim(coalesce(insrd_st, ''))) in ('', 'NAN', 'NONE', 'NULL') then null
            else upper(trim(insrd_st))
        end                                                               as state,

        case
            when insrd_zip is null then null
            else substring(
                lpad(cast(cast(insrd_zip as integer) as varchar), 5, '0'),
                1, 5
            )
        end                                                               as zip_cd,

        -- Codes
        {{ normalize_asl('asl') }}                                        as asl_normalized,
        lpad(cast(class_cd as varchar), 5, '0')                           as class_cd,

        -- Dates
        {{ parse_mixed_date('eff_dt') }}                                  as policy_eff_date,
        {{ parse_mixed_date('exp_dt') }}                                  as policy_exp_date,
        try_to_date(nullif(acc_dt, 'NULL'))                               as acc_date,
        try_to_date(nullif(rpt_dt, 'NULL'))                               as rpt_date,

        -- Categoricals
        upper(trim(pol_type))                                             as top,
        upper(trim(nullif(clm_status, 'NULL')))                           as clm_status_raw,
        nullif(loss_type, 'NULL')                                         as tol,

        -- Premium
        cast(wrt_prem as integer)                                         as wprem,

        -- Loss columns (kept as decimals; rounded in int_gl__claims_enriched)
        cast(pd_indem     as number(38, 2))                               as pd_indem,
        cast(case_rsv     as number(38, 2))                               as case_rsv,
        cast(recovery_amt as number(38, 2))                               as recovery_amt,
        cast(pd_alae      as number(38, 2))                               as p_alae_raw,
        cast(total_alae   as number(38, 2))                               as i_alae_raw

    from src

)

select * from renamed