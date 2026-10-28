
-- Fixture for dq_check_catalog
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('A key, timestamp, quantity or amount is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('conflicting_duplicate' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The same purchase_id arrived with different content' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('exact_duplicate' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('drop_extra_copies' as character varying)
 as "action", 
    
    cast('The same purchase_id arrived more than once with identical content (replayed upload); one copy is kept' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('retry_duplicate' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Same user, product, timestamp, quantity and amount as an earlier purchase_id (client retry)' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('orphan_product' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('product_id is not in the product catalog' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('orphan_user' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_id is not in users (re-checked every run in case the user arrives later)' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('user_quarantined' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The purchasing user is quarantined' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('non_positive_quantity' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Quantity is zero or negative' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('price_out_of_range' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('price_paid is not positive, exceeds the list amount, or is below min_price_ratio of it' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('before_signup' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Purchased before the user signed up' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('future_timestamp' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Purchased after the cutoff of the batch it arrived in' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('points_mismatch' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('repair' as character varying)
 as "action", 
    
    cast('points_earned differs from floor(price_paid x points_per_dollar); the rule value is used' as character varying)
 as "description"
union all
select 
    
    cast('purchases' as character varying)
 as "entity", 
    
    cast('derived_field_mismatch' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('repair' as character varying)
 as "action", 
    
    cast('day_of_week or hour_of_day disagree with purchased_at; recomputed from the timestamp' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('referral_id, referrer, sent_at or status is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('conflicting_duplicate' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The same referral_id arrived twice in one batch with different content' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('invalid_status' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('status is not sent, clicked or converted' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('orphan_referrer' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The referrer is not a valid user' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('unknown_referred_user' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('referred_user_id is not in users' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('self_referral' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('The invited email is the referrer''s own (after normalising case and +tags)' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('status_inconsistent' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Status converted without a referred user and converted_at (or the reverse)' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('existing_member' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Converted to someone who was already a member when the invite was sent' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('converted_before_sent' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('converted_at is earlier than sent_at' as character varying)
 as "description"
union all
select 
    
    cast('referrals' as character varying)
 as "entity", 
    
    cast('duplicate_send' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('Same referrer invited the same email within duplicate_send_window_hours; the later invite is quarantined' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('unparseable_or_missing' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_id or created_at is missing or cannot be parsed' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('orphan_school' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('school_id is not in schools' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('invalid_user_type' as character varying)
 as "check_name", 
    
    cast('error' as character varying)
 as "severity", 
    
    cast('quarantine' as character varying)
 as "action", 
    
    cast('user_type is not parent, teacher or supporter' as character varying)
 as "description"
union all
select 
    
    cast('users' as character varying)
 as "entity", 
    
    cast('shared_email' as character varying)
 as "check_name", 
    
    cast('warn' as character varying)
 as "severity", 
    
    cast('flag' as character varying)
 as "action", 
    
    cast('Another user has the same email; joins never use email' as character varying)
 as "description"