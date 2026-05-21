# Verisk GL pipeline — dbt project files

This bundle contains every file needed to run the Carrier_B GL transformation in dbt platform. Default dialect is **Snowflake** — if your target is something else (BigQuery, Databricks, Redshift, Postgres), the only file that needs porting is `macros/parse_mixed_date.sql` (which uses `try_to_date`).

## File placement

Drop each file into your existing dbt project at the path shown. Paths are relative to your dbt project root (the folder containing `dbt_project.yml`).

```
<your_dbt_project>/
├── dbt_project.yml                  ← MERGE the additions from dbt_project.yml.additions
├── packages.yml                     ← MERGE the additions from packages.yml.additions
│
├── models/
│   ├── staging/carrier_b/
│   │   ├── _carrier_b__sources.yml
│   │   ├── _carrier_b__models.yml
│   │   └── stg_carrier_b__transactions.sql
│   ├── intermediate/
│   │   ├── _int_gl__models.yml
│   │   ├── int_gl__filtered_transactions.sql
│   │   ├── int_gl__policies_enriched.sql
│   │   ├── int_gl__claims_enriched.sql
│   │   ├── int_gl__claims_with_sol.sql
│   │   └── int_gl__qc_flags.sql
│   └── marts/
│       ├── _marts__models.yml
│       └── fct_gl_transactions.sql
│
├── seeds/
│   ├── _seeds.yml
│   ├── asl_to_subline.csv
│   ├── asl_to_coverage.csv
│   ├── policy_size_bands.csv
│   ├── size_of_loss_bands.csv
│   └── claim_status_codes.csv
│
├── macros/
│   ├── normalize_asl.sql
│   ├── parse_mixed_date.sql
│   └── pro_rata_earned_premium.sql
│
└── tests/
    ├── assert_premium_reconciliation.sql
    ├── assert_loss_ratio_in_bounds.sql
    ├── assert_no_orphan_claims.sql
    └── assert_negative_incurred_pct.sql
```

## Setup checklist

1. Copy every file from this bundle into the matching path in your dbt project.
2. Merge the contents of `dbt_project.yml.additions` into your existing `dbt_project.yml`. Replace `verisk_gl` with your actual project name (the `name:` field at the top of `dbt_project.yml`).
3. Merge the contents of `packages.yml.additions` into your existing `packages.yml` (or create one if you don't have it).
4. Update the two source-location vars in `dbt_project.yml` to point at where Carrier_B raw lands in your warehouse:

   ```yaml
   vars:
     carrier_b_raw_database: 'YOUR_RAW_DB'
     carrier_b_raw_schema:   'YOUR_RAW_SCHEMA'
   ```

5. Run `dbt deps` to install `dbt_utils`.
6. Run `dbt seed --select tag:reference_data` to load the lookup tables (or just `dbt seed` to load all).
7. Run `dbt build --select +fct_gl_transactions` — this runs sources, seeds, models, and tests in dependency order.

## How to run for a different submission date

The pipeline uses an `eval_date` variable, defaulting to `2025-12-31`. Override per run:

```bash
dbt build --vars '{eval_date: "2026-03-31"}' --select +fct_gl_transactions
```

In dbt platform job UI, set `--vars '{eval_date: "..."}'` in the job command.

## Adding more carriers

To extend to Carrier_A, Carrier_C, etc.:

1. Create `models/staging/carrier_a/stg_carrier_a__transactions.sql` mirroring the Carrier_B staging model with the new carrier's raw column names.
2. Add `_carrier_a__sources.yml` for the new raw landing table.
3. Change `int_gl__filtered_transactions.sql` to union across carriers using `dbt_utils.union_relations`.
4. Run `dbt build --select +fct_gl_transactions`.

## Snowflake-specific calls

If you're not on Snowflake, replace these calls. Everything else is ANSI-portable:

| Snowflake | Replacement |
|---|---|
| `try_to_date(col, fmt)` | adapter-specific safe date parser (`safe.parse_date` on BigQuery, etc.) |
| `count_if(condition)` | `count(case when condition then 1 end)` |
| `lpad`, `least`, `greatest`, `datediff`, `date_part`, `trim(val, chars)` | These work on all major warehouses |

## What this bundle does NOT include

- A `dbt_project.yml` from scratch — your project already has one. The `.additions` file shows only what to add.
- An override of the `name:` field — you need to substitute your project name in the `models:` block.
- The raw landing job that gets `synthetic_carrier_b` into your warehouse — that lives upstream of dbt.
- Carrier_A / Carrier_C staging models — only Carrier_B is built here.

## Validation

Every SQL file in this bundle was simulated against the sample data in `synthetic_carrier_b.csv`, and the resulting mart matches `carrier_b_output.csv` exactly across all 22 business columns on all 350 rows. See `sample_data_dbt_breakdown.md` (in the parent folder) for the side-by-side parity report.
