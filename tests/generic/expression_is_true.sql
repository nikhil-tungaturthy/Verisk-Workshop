{% test expression_is_true(model, expression, column_name=None) %}

select *
from {{ model }}
{% if column_name is none %}
where not({{ expression }})
{%- else %}
where not({{ column_name }} {{ expression }})
{%- endif %}

{% endtest %}