{#
    pro_rata_earned_premium(wprem, eff_date, exp_date, eval_date)

    Compute the earned portion of a written premium as-of an evaluation date,
    pro-rated over the policy term.

    Formula:
        days_elapsed       = max(0, eval_date - eff_date)
        policy_term_days   = max(1, exp_date - eff_date)        -- avoid div/0
        earned_ratio       = min(1, days_elapsed / policy_term_days)
        earned_premium     = round(wprem * earned_ratio, 3)

    This matches the pandas implementation in notebook 01:
        days_elapsed = (EVAL_DATE - df['POLICY_EFF_DATE']).dt.days.clip(lower=0)
        policy_term  = (df['POLICY_EXP_DATE'] - df['POLICY_EFF_DATE']).dt.days.replace(0, 1)
        earned_ratio = (days_elapsed / policy_term).clip(upper=1.0)
        df['PREM']   = (df['WPREM'].astype(float) * earned_ratio).round(3)

    Notes:
        - If eval_date is after exp_date, the policy is fully earned (ratio capped at 1.0).
        - If eval_date is before eff_date, the policy is unearned (ratio floored at 0.0).
        - A zero-length policy (eff == exp) is treated as 1 day to avoid div/0;
          earned premium will equal written premium in that pathological case.

    Parameters:
        wprem      — written premium column or expression
        eff_date   — policy effective date column
        exp_date   — policy expiration date column
        eval_date  — evaluation date column or var

    Returns:
        NUMBER(38, 3) — earned premium, rounded to 3 decimals.
#}

{% macro pro_rata_earned_premium(wprem, eff_date, exp_date, eval_date) %}
    cast(round(
        {{ wprem }} * least(
            1.0,
            greatest(0, datediff('day', {{ eff_date }}, {{ eval_date }}))::float
            / greatest(1, datediff('day', {{ eff_date }}, {{ exp_date }}))::float
        ),
        3
    ) as number(38, 3))
{% endmacro %}
