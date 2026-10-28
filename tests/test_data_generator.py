"""
Invariants and realism checks for the completed data generator.

Clean-row invariants are checked on every row that is not listed in the
generator's injected-issues manifest; a separate test turns dirty data off
and checks the same invariants hold for every row.
"""

import json
import math
import os
import sys
from collections import Counter, defaultdict
from datetime import timedelta

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from data_generator import CartonCapsDataGenerator  # noqa: E402

PURCHASE_FIELDS = ['purchase_id', 'user_id', 'product_id', 'quantity', 'price_paid',
                   'points_earned', 'purchased_at', 'day_of_week', 'hour_of_day']
REFERRAL_FIELDS = ['referral_id', 'referrer_user_id', 'referred_email', 'referred_user_id',
                   'referral_code', 'sent_at', 'converted_at', 'status']


def build(tmp_path, dirty_rate=None, order=('purchases', 'referrals'), **sizes):
    gen = CartonCapsDataGenerator(output_dir=str(tmp_path))
    if dirty_rate is not None:
        gen.DIRTY_DATA_RATE = dirty_rate
    gen.generate_schools(sizes.get('schools', 50))
    gen.generate_users(sizes.get('users', 1000))
    gen.generate_products(sizes.get('products', 100))
    for step in order:
        if step == 'purchases':
            gen.generate_purchases(sizes.get('purchases', 10000))
        else:
            gen.generate_referrals(sizes.get('referrals', 1000))
    manifest = json.load(open(tmp_path / gen.DQ_MANIFEST_FILENAME, encoding='utf-8'))['datasets']
    return gen, manifest


def planted(manifest, dataset):
    return {i for ids in manifest.get(dataset, {}).values() for i in ids}


@pytest.fixture(scope='module')
def default_run(tmp_path_factory):
    return build(tmp_path_factory.mktemp('default'))


def clean_purchases(gen, manifest):
    bad = planted(manifest, 'purchases')
    seen, rows = set(), []
    for p in gen.purchases:
        if p['purchase_id'] in bad or p['purchase_id'] in seen:
            continue
        seen.add(p['purchase_id'])
        rows.append(p)
    return rows


def clean_referrals(gen, manifest):
    bad = planted(manifest, 'referrals')
    return [r for r in gen.referrals if r['referral_id'] not in bad]


# --- shape -----------------------------------------------------------------

def test_row_counts_and_field_contract(default_run):
    gen, _ = default_run
    assert len(gen.purchases) == 10000
    assert len(gen.referrals) == 1000
    assert list(gen.purchases[0]) == PURCHASE_FIELDS
    assert list(gen.referrals[0]) == REFERRAL_FIELDS


def test_reproducible_and_independent_of_call_order(tmp_path):
    a, _ = build(tmp_path / 'a')
    b, _ = build(tmp_path / 'b', order=('referrals', 'purchases'))
    assert a.purchases == b.purchases
    assert a.referrals == b.referrals


# --- purchases ---------------------------------------------------------------

def test_clean_purchases_respect_signup_launch_and_window(default_run):
    gen, manifest = default_run
    users = {u['user_id']: u for u in gen.users}
    products = {p['product_id']: p for p in gen.products}
    first_signup = min(u['created_at'] for u in gen.users)
    window_end = gen.end_date + timedelta(days=1)
    for p in clean_purchases(gen, manifest):
        assert p['purchased_at'] >= users[p['user_id']]['created_at']
        assert p['purchased_at'].date() >= products[p['product_id']]['created_at'].date()
        assert first_signup <= p['purchased_at'] < window_end


def test_clean_purchase_amounts_follow_business_rules(default_run):
    gen, manifest = default_run
    products = {p['product_id']: p for p in gen.products}
    for p in clean_purchases(gen, manifest):
        product = products[p['product_id']]
        list_price = round(product['price'] * p['quantity'], 2)
        assert p['quantity'] >= 1
        assert 0 < p['price_paid'] <= list_price
        assert p['price_paid'] >= round(list_price * 0.70, 2) - 0.01  # max promo is 30% off
        assert p['points_earned'] == math.floor(round(p['price_paid'] * product['points_per_dollar'], 6))
        assert p['day_of_week'] == p['purchased_at'].strftime('%A')
        assert p['hour_of_day'] == p['purchased_at'].hour


def test_purchase_ids_unique_apart_from_planted_exact_duplicates(default_run):
    gen, manifest = default_run
    counts = Counter(p['purchase_id'] for p in gen.purchases)
    duplicated = {pid for pid, c in counts.items() if c > 1}
    assert duplicated == set(manifest['purchases']['exact_duplicate'])


def test_purchase_frequency_is_heavy_tailed(default_run):
    gen, manifest = default_run
    per_user = Counter(p['user_id'] for p in clean_purchases(gen, manifest))
    counts = sorted((per_user.get(u['user_id'], 0) for u in gen.users), reverse=True)
    top_decile_share = sum(counts[:len(counts) // 10]) / sum(counts)
    assert top_decile_share > 0.35
    assert 0.05 < counts.count(0) / len(counts) < 0.25  # some signups never scan


def test_weekends_busier_than_weekdays(default_run):
    gen, manifest = default_run
    by_weekday = Counter(p['purchased_at'].weekday() for p in clean_purchases(gen, manifest))
    weekday_avg = sum(by_weekday[d] for d in range(5)) / 5
    weekend_avg = (by_weekday[5] + by_weekday[6]) / 2
    assert weekend_avg > 1.2 * weekday_avg


def test_every_school_has_a_district_with_an_income_level(default_run):
    gen, _ = default_run
    districts = {(d['city'], d['state']): d for d in gen.districts}
    assert all((s['city'], s['state']) in districts for s in gen.schools)
    assert {d['income_level'] for d in gen.districts} == {'low', 'middle', 'high'}


def test_spending_depends_on_district_income_and_user_type(default_run):
    gen, manifest = default_run
    products = {p['product_id']: p for p in gen.products}
    users = {u['user_id']: u for u in gen.users}
    income = {(d['city'], d['state']): d['income_level'] for d in gen.districts}
    school_income = {s['school_id']: income[(s['city'], s['state'])] for s in gen.schools}
    list_price, quantity, promo = defaultdict(list), defaultdict(list), defaultdict(list)
    for p in clean_purchases(gen, manifest):
        user = users[p['user_id']]
        level = school_income[user['school_id']]
        product = products[p['product_id']]
        list_price[level].append(product['price'])
        promo[level].append(p['price_paid'] < round(product['price'] * p['quantity'], 2))
        quantity[user['user_type']].append(p['quantity'])
    mean = lambda xs: sum(xs) / len(xs)
    assert mean(list_price['high']) > mean(list_price['middle']) > mean(list_price['low'])
    assert mean(promo['low']) > mean(promo['high'])
    assert mean(quantity['teacher']) > mean(quantity['parent']) > mean(quantity['supporter'])


def test_planted_purchase_issues_are_detectable(default_run):
    gen, manifest = default_run
    products = {p['product_id']: p for p in gen.products}
    users = {u['user_id']: u for u in gen.users}
    rows = {p['purchase_id']: p for p in gen.purchases}
    issues = manifest['purchases']
    assert all(len(ids) >= 2 for ids in issues.values())
    assert all(rows[i]['product_id'] not in products for i in issues['orphan_product'])
    assert all(rows[i]['quantity'] <= 0 for i in issues['non_positive_quantity'])
    assert all(rows[i]['purchased_at'] < users[rows[i]['user_id']]['created_at']
               for i in issues['before_signup'])
    natural_key = Counter((p['user_id'], p['product_id'], p['purchased_at'])
                          for p in {p['purchase_id']: p for p in gen.purchases}.values())
    assert all(natural_key[(rows[i]['user_id'], rows[i]['product_id'], rows[i]['purchased_at'])] == 2
               for i in issues['retry_duplicate'])


# --- referrals ---------------------------------------------------------------

def test_clean_referral_status_is_consistent(default_run):
    gen, manifest = default_run
    users = {u['user_id']: u for u in gen.users}
    for r in clean_referrals(gen, manifest):
        assert r['status'] in {'sent', 'clicked', 'converted'}
        if r['status'] == 'converted':
            referred = users[r['referred_user_id']]
            assert r['converted_at'] == referred['created_at']
            assert r['referred_email'] == referred['email']
            assert r['sent_at'] <= r['converted_at']
            assert r['converted_at'] - r['sent_at'] <= timedelta(days=9)
        else:
            assert r['referred_user_id'] is None and r['converted_at'] is None
        assert r['referred_email'] != users[r['referrer_user_id']]['email']


def test_referral_funnel_rates(default_run):
    gen, manifest = default_run
    rows = clean_referrals(gen, manifest)
    status = Counter(r['status'] for r in rows)
    conversion = status['converted'] / len(rows)
    clicked_or_better = (status['clicked'] + status['converted']) / len(rows)
    assert 0.10 <= conversion <= 0.30
    assert 0.35 <= clicked_or_better <= 0.55


def test_each_user_converts_once_and_codes_are_stable(default_run):
    gen, manifest = default_run
    converted = [r['referred_user_id'] for r in clean_referrals(gen, manifest) if r['status'] == 'converted']
    assert len(converted) == len(set(converted))
    codes_per_referrer = {}
    for r in gen.referrals:
        codes_per_referrer.setdefault(r['referrer_user_id'], set()).add(r['referral_code'])
    assert all(len(codes) == 1 for codes in codes_per_referrer.values())


def test_referral_network_has_chains_and_a_heavy_tail(default_run):
    gen, manifest = default_run
    rows = clean_referrals(gen, manifest)
    referred_by = {r['referred_user_id']: r['referrer_user_id'] for r in rows if r['status'] == 'converted'}
    chained = [uid for uid, referrer in referred_by.items() if referrer in referred_by]
    assert chained, "expected at least one referred user who was referred by a referred user"
    sends = Counter(r['referrer_user_id'] for r in rows)
    assert len(sends) / len(gen.users) < 0.4           # most users never refer
    assert max(sends.values()) >= 10 * sorted(sends.values())[len(sends) // 2]


def test_referral_share_of_signups_grows(default_run):
    gen, manifest = default_run
    referred = {r['referred_user_id'] for r in clean_referrals(gen, manifest) if r['status'] == 'converted'}
    users = sorted(gen.users, key=lambda u: u['created_at'])
    half = len(users) // 2
    early = sum(u['user_id'] in referred for u in users[:half]) / half
    late = sum(u['user_id'] in referred for u in users[half:]) / (len(users) - half)
    assert late > early * 1.5


def test_planted_referral_issues_are_detectable(default_run):
    gen, manifest = default_run
    users = {u['user_id']: u for u in gen.users}
    rows = {r['referral_id']: r for r in gen.referrals}
    issues = manifest['referrals']
    assert all(len(ids) >= 2 for ids in issues.values())
    for i in issues['self_referral']:
        local = rows[i]['referred_email'].split('@')[0].split('+')[0]
        assert users[rows[i]['referrer_user_id']]['email'].startswith(local + '@')
    for i in issues['existing_member_converted']:
        assert users[rows[i]['referred_user_id']]['created_at'] < rows[i]['sent_at']
    for i in issues['status_mismatch']:
        assert rows[i]['status'] == 'converted' and rows[i]['referred_user_id'] is None
    for i in issues['converted_before_sent']:
        assert rows[i]['converted_at'] < rows[i]['sent_at']


# --- dirty data off ------------------------------------------------------------

def test_clean_mode_has_no_planted_issues(tmp_path):
    gen, manifest = build(tmp_path, dirty_rate=0)
    assert planted(manifest, 'purchases') == set() and planted(manifest, 'referrals') == set()
    assert len({p['purchase_id'] for p in gen.purchases}) == len(gen.purchases) == 10000
    products = {p['product_id'] for p in gen.products}
    assert all(p['product_id'] in products and p['quantity'] >= 1 for p in gen.purchases)
    assert all((r['status'] == 'converted') == (r['referred_user_id'] is not None) for r in gen.referrals)


# --- settings file ---------------------------------------------------------------

SETTINGS_FILE = os.path.join(os.path.dirname(__file__), '..', 'generator_settings.json')


@pytest.fixture
def settings_copy(tmp_path):
    """A writable copy of the settings; the defaults are reloaded afterwards."""
    raw = json.load(open(SETTINGS_FILE, encoding='utf-8'))
    path = tmp_path / 'settings.json'

    def write(edit=None):
        data = json.loads(json.dumps(raw))
        if edit:
            edit(data)
        path.write_text(json.dumps(data), encoding='utf-8')
        return str(path)
    yield write
    CartonCapsDataGenerator.load_settings(SETTINGS_FILE)


def test_every_setting_has_a_description_and_value():
    raw = json.load(open(SETTINGS_FILE, encoding='utf-8'))
    settings = [(section, name, s) for section, group in raw.items() if isinstance(group, dict)
                for name, s in group.items() if isinstance(s, dict)]
    assert len(settings) >= 30
    for section, name, s in settings:
        assert set(s) == {'description', 'value'}, f"{section}.{name}"
        assert len(s['description']) > 20, f"{section}.{name} needs a real description"


def test_settings_file_drives_the_data(tmp_path, settings_copy):
    def no_dirty_rows_and_no_churn(data):
        data['data_quality']['dirty_data_rate']['value'] = 0
        data['purchases']['monthly_churn']['value'] = {'heavy': 0, 'regular': 0, 'light': 0}
    CartonCapsDataGenerator.load_settings(settings_copy(no_dirty_rows_and_no_churn))
    assert CartonCapsDataGenerator.MONTHLY_CHURN == {'heavy': 0, 'regular': 0, 'light': 0}
    gen, manifest = build(tmp_path, users=300, purchases=2000, referrals=200)
    assert planted(manifest, 'purchases') == set() and planted(manifest, 'referrals') == set()


def test_bad_settings_are_rejected_and_leave_defaults_in_place(settings_copy):
    before = CartonCapsDataGenerator.ACTIVITY_SEGMENTS

    def shares_do_not_add_up(data):
        data['purchases']['activity_segments']['value']['heavy']['share'] = 0.5
    with pytest.raises(ValueError, match='activity_segments shares add up to 1.4'):
        CartonCapsDataGenerator.load_settings(settings_copy(shares_do_not_add_up))

    def missing_setting(data):
        del data['referrals']['reinvite_share']
    with pytest.raises(ValueError, match='missing setting referrals.reinvite_share'):
        CartonCapsDataGenerator.load_settings(settings_copy(missing_setting))

    def churn_above_one(data):
        data['purchases']['monthly_churn']['value']['light'] = 1.5
    with pytest.raises(ValueError, match='monthly_churn.light = 1.5'):
        CartonCapsDataGenerator.load_settings(settings_copy(churn_above_one))
    assert CartonCapsDataGenerator.ACTIVITY_SEGMENTS == before
