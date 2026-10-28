"""Paths and source contracts shared by every pipeline step."""

import os
from dataclasses import dataclass
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parents[1]
DBT_PROJECT_DIR = REPO_ROOT / 'transform'

# Column contract for every source entity, in file order. Ingest rejects a
# file whose header doesn't match.
CONTRACTS = {
    'schools': ('school_id', 'name', 'address', 'city', 'state', 'zip_code', 'created_at'),
    'users': ('user_id', 'first_name', 'last_name', 'email', 'school_id', 'created_at', 'user_type'),
    'products': ('product_id', 'name', 'category', 'price', 'points_per_dollar', 'created_at'),
    'districts': ('district', 'city', 'state', 'income_level', 'median_household_income'),
    'purchases': ('purchase_id', 'user_id', 'product_id', 'quantity', 'price_paid',
                  'points_earned', 'purchased_at', 'day_of_week', 'hour_of_day'),
    'referrals': ('referral_id', 'referrer_user_id', 'referred_email', 'referred_user_id',
                  'referral_code', 'sent_at', 'converted_at', 'status'),
}
# Small reference entities arrive as full snapshots; the others as deltas.
# districts is external reference data (income by school district).
SNAPSHOT_ENTITIES = ('schools', 'users', 'products', 'districts')
EVENT_ENTITIES = ('purchases', 'referrals')

# DuckDB 2.0 writes new database files in its newest storage format by default,
# which DuckDB 1.x tools (editor extensions, older CLIs) can't open. The warehouse
# is written in the v1.0 format instead, readable by every DuckDB from 0.10 on.
# The format is fixed when the file is created; later connections keep it.
# transform/profiles.yml sets the same option for dbt.
STORAGE_COMPATIBILITY_VERSION = 'v1.0.0'


def connect_warehouse(path: Path) -> duckdb.DuckDBPyConnection:
    """Open (or create) a warehouse file in the widely readable storage format."""
    return duckdb.connect(str(path), config={'storage_compatibility_version': STORAGE_COMPATIBILITY_VERSION})


@dataclass(frozen=True)
class Paths:
    """Where one pipeline instance keeps its files. Tests point this at a temp dir."""

    home: Path

    @property
    def data(self) -> Path:          # generator output
        return self.home / 'data'

    @property
    def landing(self) -> Path:       # dated batches, as they would arrive from production
        return self.home / 'landing'

    @property
    def warehouse(self) -> Path:     # the DuckDB database
        return self.home / 'warehouse' / 'carton_caps.duckdb'

    @property
    def exports(self) -> Path:       # gold tables as Parquet
        return self.home / 'exports'


def default_paths() -> Paths:
    return Paths(Path(os.environ.get('CARTON_CAPS_HOME', REPO_ROOT)).resolve())
