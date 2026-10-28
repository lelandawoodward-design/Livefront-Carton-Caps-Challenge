"""
End to end: generate -> feed -> ingest -> dbt build, then check the outputs
against independent calculations from the generator's own files.
"""

import csv
import json
import math
from collections import defaultdict
from decimal import Decimal

import duckdb
import pytest

from conftest import REPO_ROOT, copy_home
from pipeline import feed, ingest, report, steps, transform

# Planted issue (generator manifest) -> check the pipeline must report for it.
EXPECTED_CHECK = {
    'purchases': {
        'exact_duplicate': 'exact_duplicate',
        'retry_duplicate': 'retry_duplicate',
        'orphan_product': 'orphan_product',
        'non_positive_quantity': 'non_positive_quantity',
        'before_signup': 'before_signup',
        'points_mismatch': 'points_mismatch',
    },
    'referrals': {
        'self_referral': 'self_referral',
        'existing_member_converted': 'existing_member',
        'duplicate_send': 'duplicate_send',
        'status_mismatch': 'status_inconsistent',
        'converted_before_sent': 'converted_before_sent',
    },
}
# Planted issues that keep the record (dropped copy, or repaired value).
KEEPS_RECORD = {'exact_duplicate', 'points_mismatch'}


def read_csv(path):
    with open(path, newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))


@pytest.fixture(scope='module')
def built(generated, tmp_path_factory):
    paths = copy_home(generated, tmp_path_factory.mktemp('built'))
    feed.build_batches(paths.data, paths.landing, 'monthly')
    ingest.ingest(paths)
    transform.run_dbt(paths, 'build', quiet=True)
    manifest = json.load(open(paths.data / 'injected_dq_issues.json', encoding='utf-8'))['datasets']
    return paths, manifest


def query(paths, sql):
    con = duckdb.connect(str(paths.warehouse))
    try:
        return con.execute(sql).fetchall()
    finally:
        con.close()


@pytest.mark.parametrize('dataset,table', [('purchases', 'purchases_checked'),
                                           ('referrals', 'referrals_checked')])
def test_every_planted_issue_is_caught_and_nothing_else(built, dataset, table):
    paths, manifest = built
    issues = {key: (checks, status) for key, checks, status in
              query(paths, f'select record_key, dq_issues, dq_status from silver.{table}')}
    planted = {}
    for issue, ids in manifest[dataset].items():
        for record_id in ids:
            planted[str(record_id)] = issue
    for record_id, issue in planted.items():
        checks, status = issues[record_id]
        assert EXPECTED_CHECK[dataset][issue] in checks, (record_id, issue, checks)
        assert status == ('valid' if issue in KEEPS_RECORD else 'quarantined'), (record_id, issue, status)
    false_positives = {k: v for k, v in issues.items() if k not in planted and v[0]}
    assert false_positives == {}


def test_funds_raised_match_an_independent_calculation(built):
    """Recompute dollars raised straight from the generator's CSVs and the manifest."""
    paths, manifest = built
    products = {p['product_id']: int(p['points_per_dollar']) for p in read_csv(paths.data / 'products.csv')}
    excluded = {str(i) for issue, ids in manifest['purchases'].items() if issue not in KEEPS_RECORD for i in ids}
    points, seen = 0, set()
    for row in read_csv(paths.data / 'purchases.csv'):
        if row['purchase_id'] in excluded or row['purchase_id'] in seen:
            continue
        seen.add(row['purchase_id'])
        points += math.floor(round(float(row['price_paid']) * products[row['product_id']], 6))
    expected = Decimal(points) / 100
    for table in ('fct_purchases', 'school_daily_activity', 'school_engagement_monthly'):
        assert query(paths, f'select sum(dollars_raised) from gold.{table}')[0][0] == expected, table


def test_referral_funnel_matches_an_independent_calculation(built):
    paths, manifest = built
    excluded = {str(i) for ids in manifest['referrals'].values() for i in ids}
    valid = [r for r in read_csv(paths.data / 'referrals.csv') if r['referral_id'] not in excluded]
    converted = sum(r['status'] == 'converted' for r in valid)
    clicked = sum(r['status'] in ('clicked', 'converted') for r in valid)
    invites, f_clicked, f_converted = query(paths, """
        select sum(invites), sum(clicked), sum(converted)
        from gold.referral_funnel_monthly where referrer_segment = 'all'""")[0]
    assert (invites, f_clicked, f_converted) == (len(valid), clicked, converted)


def test_cohort_retention_matches_an_independent_calculation(built):
    """Month-1 retention for the July 2023 cohort, recomputed from the CSVs."""
    paths, manifest = built
    users = {u['user_id']: u['created_at'][:7] for u in read_csv(paths.data / 'users.csv')}
    cohort = {uid for uid, month in users.items() if month == '2023-07'}
    excluded = {str(i) for issue, ids in manifest['purchases'].items() if issue not in KEEPS_RECORD for i in ids}
    excluded_referrals = {str(i) for ids in manifest['referrals'].values() for i in ids}
    active = set()
    for row in read_csv(paths.data / 'purchases.csv'):
        if row['purchase_id'] not in excluded and row['user_id'] in cohort and row['purchased_at'][:7] == '2023-08':
            active.add(row['user_id'])
    for row in read_csv(paths.data / 'referrals.csv'):
        if row['referral_id'] not in excluded_referrals and row['referrer_user_id'] in cohort \
                and row['sent_at'][:7] == '2023-08':
            active.add(row['referrer_user_id'])
    size, active_users = query(paths, """
        select cohort_size, active_users from gold.cohort_retention
        where cohort_month = date '2023-07-01' and channel = 'all' and months_since_signup = 1""")[0]
    assert (size, active_users) == (len(cohort), len(active))


def test_referral_network_matches_the_source(built):
    paths, manifest = built
    excluded = {str(i) for ids in manifest['referrals'].values() for i in ids}
    referred_by = {r['referred_user_id']: r['referrer_user_id'] for r in read_csv(paths.data / 'referrals.csv')
                   if r['status'] == 'converted' and r['referral_id'] not in excluded}

    def generation(uid):
        n = 0
        while uid in referred_by:
            uid, n = referred_by[uid], n + 1
        return n

    expected = defaultdict(int)
    for uid in referred_by:
        expected[generation(uid)] += 1
    actual = dict(query(paths, """
        select referral_generation, count(*) from gold.dim_users
        where acquisition_channel = 'referral' group by 1"""))
    assert actual == dict(expected)


def test_spending_mart_reflects_income_and_user_type(built):
    paths, _ = built
    price = dict(query(paths, """
        select s.income_level, sum(p.list_amount) / sum(p.quantity)
        from gold.fct_purchases as p join gold.dim_schools as s on s.school_id = p.school_id
        group by 1"""))
    assert price['high'] > price['middle'] > price['low']
    units = dict(query(paths, """
        select user_type, sum(units_per_purchase * purchases) / sum(purchases)
        from gold.spending_by_segment group by 1"""))
    assert units['teacher'] > units['parent'] > units['supporter']
    mart, facts = query(paths, """
        select (select sum(purchases) from gold.spending_by_segment),
               (select count(*) from gold.fct_purchases)""")[0]
    assert mart == facts


def test_incremental_build_equals_full_rebuild(generated, tmp_path):
    paths = copy_home(generated, tmp_path / 'home')
    assert steps.demo_incremental(paths) is True


def test_sample_queries_all_run(built):
    paths, _ = built
    output = report.run_report(paths)
    names = [name for name, _ in report.load_queries()]
    assert len(names) >= 8
    for name in names:
        assert f'## {name}' in output


def test_unit_test_fixture_matches_the_check_catalog():
    seed = (REPO_ROOT / 'transform' / 'seeds' / 'dq_check_catalog.csv').read_text(encoding='utf-8')
    fixture = (REPO_ROOT / 'transform' / 'tests' / 'fixtures' / 'dq_check_catalog_fixture.csv').read_text(encoding='utf-8')
    assert fixture == seed, 'copy transform/seeds/dq_check_catalog.csv to tests/fixtures/dq_check_catalog_fixture.csv'


def storage_version(path):
    """The storage version number in a DuckDB file header (64 = readable by DuckDB 0.10 through 1.x)."""
    with open(path, 'rb') as f:
        header = f.read(20)
    assert header[8:12] == b'DUCK'
    return int.from_bytes(header[12:20], 'little')


def test_warehouse_is_readable_by_duckdb_1x(built, tmp_path):
    # Created by ingest, then written by dbt: stays in the v1.0 format.
    paths, _ = built
    assert storage_version(paths.warehouse) == 64
    # Created by dbt itself (dbt seed on an empty folder): profiles.yml sets the same format.
    fresh = type(paths)(tmp_path / 'fresh')
    fresh.warehouse.parent.mkdir(parents=True)
    transform.run_dbt(fresh, 'seed', quiet=True)
    assert storage_version(fresh.warehouse) == 64
