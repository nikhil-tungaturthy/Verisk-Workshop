{{
    config(
        materialized='view',
        tags=['intermediate', 'gl']
    )
}}

{#
    GL filter: keep only ASL codes 171, 172, 181, 182.

    Non-GL codes (e.g., 17.65, 19.x) are dropped here. In a multi-carrier
    deployment this is also the natural place to UNION across per-carrier
    staging models using dbt_utils.union_relations.
#}

select *
from {{ ref('stg_carrier_b__transactions') }}
where asl_normalized in ('171', '172', '181', '182')