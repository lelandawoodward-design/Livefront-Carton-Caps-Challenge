{# Fails for every row where the expression is false or null. Usable at model or column level. #}
{% test expression_is_true(model, expression, column_name=none) %}
    select * from {{ model }} where not coalesce(({{ expression }}), false)
{% endtest %}


{# Fails for every duplicated combination of the given columns. #}
{% test unique_combination(model, columns) %}
    select {{ columns | join(', ') }}, count(*) as n
    from {{ model }}
    group by {{ columns | join(', ') }}
    having count(*) > 1
{% endtest %}
