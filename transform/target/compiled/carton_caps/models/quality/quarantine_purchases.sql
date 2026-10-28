

-- Purchases held back from gold, with why. Re-checked on every run.
select
    record_key,
    purchase_id,
    user_id,
    product_id,
    quantity,
    price_paid,
    points_reported,
    purchased_at,
    dq_issues_text as issues,
    first_batch_id,
    last_batch_id,
    evaluated_batch_id
from "carton_caps"."silver"."int_purchases_checked"
where dq_status = 'quarantined'