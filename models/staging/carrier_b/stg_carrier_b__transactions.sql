{{
    config(
        materialized='view',
        tags=['staging', 'carrier_b']
    )
}}

/*
    Carrier_B raw → standardized column names and types.

    Responsibilities at this layer:
        - rename columns to project standards (POL_NBR → policy_id, etc.)
        - cast to target types (varchar / integer / date / number)
        - parse mixed-format date strings via parse_mixed_date macro
        - normalize ASL via normalize_asl macro
        - zero-pad ZIP and class code
        - drop PII columns (insrd_name, insrd_addr_1, insrd_city)

    Explicitly NOT responsibilities of this layer:
        - any filtering (GL filter happens in int_gl__filtered_transactions)
        - any joins (enrichment happens in int_gl__policies_enriched)
        - any business logic (size bands, SOL, QC flags, etc.)
*/

with src as (

    select * from {{ source('carrier_b_raw', 'synthetic_carrier_b') }}

),

renamed as (

    select
        -----------------------------------------------------------------------
        -- Tracking columns (carrier + submission identifiers)
        -----------------------------------------------------------------------
        '{{ var("carrier_code") }}'                                       as carrier_code,
        '{{ var("carrier_code") }}_'
            || replace('{{ var("eval_date") }}', '-', '')                 as submission_id,
        cast('{{ var("eval_date") }}' as date)                            as eval_date,

        -----------------------------------------------------------------------
        -- Identifiers
        -----------------------------------------------------------------------
        cast(pol_nbr as varchar)                                          as policy_id,
        claim_nbr                                                         as claim_id,
        cast(null as varchar)                                             as location_id,
        cast(null as varchar)                                             as claimant_id,

        -----------------------------------------------------------------------
        -- Geography
        -- Note: insrd_name / insrd_addr_1 / insrd_city are PII and are
        -- deliberately omitted from the select list at this layer.
        -----------------------------------------------------------------------
        case
            when upper(trim(coalesce(insrd_st, ''))) in ('', 'NAN', 'NONE') then null
            else upper(trim(insrd_st))
        end                                                               as state,

        case
            when insrd_zip is null then null
            else substring(
                lpad(cast(cast(insrd_zip as integer) as varchar), 5, '0'),
                1, 5
            )
        end                                                               as zip_cd,

        -----------------------------------------------------------------------
        -- Codes
        -----------------------------------------------------------------------
        {{ normalize_asl('asl') }}                                        as asl_normalized,
        lpad(cast(class_cd as varchar), 5, '0')                           as class_cd,

        -----------------------------------------------------------------------
        -- Dates (mixed-format parsing happens here)
        -----------------------------------------------------------------------
        {{ parse_mixed_date('eff_dt') }}                                  as policy_eff_date,
        {{ parse_mixed_date('exp_dt') }}                                  as policy_exp_date,
        acc_dt                                                            as acc_date,
        rpt_dt                                                            as rpt_date,

        -----------------------------------------------------------------------
        -- Categoricals
        -----------------------------------------------------------------------
        upper(trim(pol_type))                                             as top,
        upper(trim(clm_status))                                           as clm_status_raw,
        loss_type                                                         as tol,

        -----------------------------------------------------------------------
        -- Premium (kept as integer at staging; downstream multiplies by float)
        -----------------------------------------------------------------------
        cast(wrt_prem as integer)                                         as wprem,

        -----------------------------------------------------------------------
        -- Loss columns (decimal types preserved; rounding happens at int layer)
        -----------------------------------------------------------------------
        cast(pd_indem     as number(38, 2))                               as pd_indem,
        cast(case_rsv     as number(38, 2))                               as case_rsv,
        cast(recovery_amt as number(38, 2))                               as recovery_amt,
        cast(pd_alae      as number(38, 2))                               as p_alae_raw,
        cast(total_alae   as number(38, 2))                               as i_alae_raw

    from src

)

select * from renamed
