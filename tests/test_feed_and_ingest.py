"""Landing batches and bronze ingestion: completeness, idempotency, and rejection of bad batches."""

import csv

import duckdb
import pytest

from conftest import copy_home
from pipeline.config import CONTRACTS
from pipeline.feed import build_batches
from pipeline.ingest import IngestError, ingest


def read_csv(path):
    with open(path, newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))


@pytest.fixture
def home(generated, tmp_path):
    paths = copy_home(generated, tmp_path / 'home')
    build_batches(paths.data, paths.landing, 'monthly')
    return paths


def batch_dirs(paths):
    return sorted(paths.landing.glob('batch=*'))


def test_every_purchase_lands_exactly_once(home):
    source = read_csv(home.data / 'purchases.csv')
    landed = [row for d in batch_dirs(home) for row in read_csv(d / 'purchases.csv')]
    assert len(landed) == len(source)
    assert sorted(map(tuple, (r.values() for r in landed))) == sorted(map(tuple, (r.values() for r in source)))


def test_snapshots_only_grow_and_end_complete(home):
    sizes = [len(read_csv(d / 'users.csv')) for d in batch_dirs(home)]
    assert sizes == sorted(sizes)
    assert sizes[-1] == len(read_csv(home.data / 'users.csv'))


def test_referrals_are_change_data(home):
    """Each referral's final state is its last emission; a few appear twice (clicked, then converted)."""
    final = {}
    emissions = {}
    for d in batch_dirs(home):
        for row in read_csv(d / 'referrals.csv'):
            final[row['referral_id']] = row
            emissions[row['referral_id']] = emissions.get(row['referral_id'], 0) + 1
    source = {r['referral_id']: r for r in read_csv(home.data / 'referrals.csv')}
    # duplicate_send rows reuse no ids, so ids are unique in the source
    assert final == source
    assert any(n > 1 for n in emissions.values())


def test_ingest_loads_everything_once(home):
    first = ingest(home)
    second = ingest(home)
    assert len(first['batches']) == len(batch_dirs(home))
    assert second['batches'] == [] and sum(second['rows'].values()) == 0
    con = duckdb.connect(str(home.warehouse))
    try:
        for entity in CONTRACTS:
            landed = sum(len(read_csv(d / f'{entity}.csv')) for d in batch_dirs(home))
            assert con.execute(f'select count(*) from bronze.{entity}').fetchone()[0] == landed
    finally:
        con.close()


def test_ingest_upto_leaves_later_batches_for_the_next_run(home):
    dirs = batch_dirs(home)
    cutoff = dirs[2].name.split('=')[1]
    assert ingest(home, upto=cutoff)['batches'] == [d.name.split('=')[1] for d in dirs[:3]]
    assert len(ingest(home)['batches']) == len(dirs) - 3


def test_schema_drift_rejects_the_whole_batch(home):
    target = batch_dirs(home)[0]
    rows = read_csv(target / 'purchases.csv')
    with open(target / 'purchases.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(CONTRACTS['purchases']) + ['coupon_code'])
        writer.writeheader()
        writer.writerows(rows)
    with pytest.raises(IngestError, match='header does not match'):
        ingest(home)
    con = duckdb.connect(str(home.warehouse))
    try:
        # Nothing from the batch landed, not even the files that were fine, and the rejection is logged.
        assert con.execute('select count(*) from meta.ingested_files').fetchone()[0] == 0
        assert con.execute("select count(*) from meta.ingestion_log where status = 'rejected'").fetchone()[0] == 1
    finally:
        con.close()


def test_a_file_changed_after_ingest_is_rejected(home):
    ingest(home)
    target = batch_dirs(home)[0] / 'schools.csv'
    target.write_text(target.read_text(encoding='utf-8').replace('Main St', 'Main Street', 1), encoding='utf-8')
    with pytest.raises(IngestError, match='changed after it was ingested'):
        ingest(home)
