{{ config(materialized='view') }}

-- Every bronze referral row, typed. A referral can appear in several batches as
-- its state changes; int_referrals_checked keeps the latest version.
-- The invited email is replaced by a keyed hash here.
select
    coalesce(cast(try_cast(referral_id as bigint) as varchar),
             'unparsed:' || _source_file || ':' || _row_number) as record_key,
    try_cast(referral_id as bigint)          as referral_id,
    try_cast(referrer_user_id as integer)    as referrer_user_id,
    {{ email_hash('referred_email') }}       as referred_email_hash,
    try_cast(referred_user_id as integer)    as referred_user_id,
    nullif(trim(referral_code), '')          as referral_code,
    try_cast(sent_at as timestamp)           as sent_at,
    try_cast(converted_at as timestamp)      as converted_at,
    lower(trim(status))                      as status,
    md5(concat_ws('|',
        coalesce(referral_id, '~'), coalesce(referrer_user_id, '~'), coalesce(referred_email, '~'),
        coalesce(referred_user_id, '~'), coalesce(referral_code, '~'), coalesce(sent_at, '~'),
        coalesce(converted_at, '~'), coalesce(status, '~')
    ))                                       as content_hash,
    _batch_id,
    _row_number,
    _source_file
from {{ source('bronze', 'referrals') }}
