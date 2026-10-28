"""
Carton Caps Data Generator

This script generates synthetic data for the Carton Caps analytics pipeline challenge.
Some methods are already implemented, while others need to be completed by the candidate.

Usage:
    python data_generator.py

This will generate several CSV files in the ./data/ directory.
"""

import random
import sqlite3
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import csv
import os
import bisect
import heapq
import json
import math
import warnings


class CartonCapsDataGenerator:
    """Generate synthetic data for Carton Caps analytics pipeline."""

    # ==================================================================
    # Behaviour settings for generate_purchases(), generate_districts() and
    # generate_referrals().
    #
    # Every number below is an assumption, not a measured fact. They are
    # class attributes, so a caller can change one without editing code,
    # e.g. ``gen.DIRTY_DATA_RATE = 0``. docs/data_generation.md explains
    # the math behind each one from the ground up.
    #
    # Two kinds of number appear:
    #   * Shares and probabilities, between 0 and 1: 0.30 means 30% of
    #     users, or 30% of the time.
    #   * Weights: relative likelihoods. Only the ratios matter, so
    #     {1: 60, 2: 25} means "1 is 2.4 times as likely as 2". Weights
    #     don't have to add up to 1 or to 100. The chance of an option is
    #     its weight divided by the sum of all the weights.
    # ==================================================================

    # ---------------- Data quality ----------------
    # Share of purchase and referral rows deliberately corrupted so the
    # pipeline's quality checks have something to catch: 0.01 = 1% of rows,
    # with at least 2 rows of each issue type. Set to 0 for clean data.
    DIRTY_DATA_RATE = 0.01
    # File that lists the id of every corrupted row (read by the tests, never by the pipeline).
    DQ_MANIFEST_FILENAME = 'injected_dq_issues.json'

    # ---------------- Purchases: who buys, and how often ----------------
    # Every user is put in one activity segment, which sets how often they buy.
    #   share  fraction of users in the segment (the four add up to 1.0)
    #   rate   purchases per active day relative to a light user
    #          (heavy = 8.0 means a heavy user buys 8x as often as a light one)
    ACTIVITY_SEGMENTS = {
        #            share  rate
        'heavy':    (0.10,  8.0),
        'regular':  (0.30,  3.0),
        'light':    (0.45,  1.0),
        'inactive': (0.15,  0.0),   # signed up but never scans a receipt
    }

    # ---------------- Purchases: churn ----------------
    # Monthly churn: the chance that a user who is still buying stops for good during
    # a given month. Checked every 30 days from signup; a user who churns stops at a
    # random point in that month. For comparison, consumer subscriptions typically
    # lose 5-10% of customers a month (about 6.5% on average for B2C), replenishment
    # products (regular purchases like groceries) under 4%, and the best businesses
    # under 3%. Light users churn like a typical consumer product, heavy users like the
    # best. After a year that leaves about 78% of heavy, 61% of regular and 37% of light
    # users still buying (0.98^12, 0.96^12 and 0.92^12).
    MONTHLY_CHURN = {'heavy': 0.02, 'regular': 0.04, 'light': 0.08}
    # Referred users churn 25% less: monthly churn is multiplied by 0.75
    # (1.5% heavy, 3% regular, 6% light).
    REFERRED_CHURN_MULTIPLIER = 0.75
    # Every user who buys makes a first purchase at a random moment within this many
    # days of signing up. It is the referral program's "qualifying action".
    FIRST_PURCHASE_WITHIN_DAYS = 7

    # ---------------- Purchases: which category ----------------
    # Weights for picking a product category, by user type. Example: a parent's
    # weights add up to 1.4 + 1.3 + 0.9 + 1.2 + 0.9 = 5.7, so a parent picks
    # Breakfast 1.4 / 5.7 = 25% of the time and Pantry 0.9 / 5.7 = 16% of the time.
    CATEGORY_PREFERENCES = {
        'parent':    {'Breakfast': 1.4, 'Snacks': 1.3, 'Beverages': 0.9, 'Dairy': 1.2, 'Pantry': 0.9},
        'teacher':   {'Breakfast': 0.8, 'Snacks': 1.5, 'Beverages': 1.3, 'Dairy': 0.7, 'Pantry': 0.8},
        'supporter': {'Breakfast': 0.8, 'Snacks': 0.8, 'Beverages': 1.2, 'Dairy': 0.9, 'Pantry': 1.4},
    }

    # ---------------- Spending: by user type ----------------
    # Weights for how many units are bought in one purchase. These happen to add
    # up to 100, so they read as percentages: a parent buys 1 unit 60% of the time,
    # 2 units 25%, 3 units 10% and 4 units 5%. Teachers buy more (stocking a
    # classroom); supporters (grandparents, neighbours) mostly buy a single item.
    QUANTITY_WEIGHTS = {
        'parent':    {1: 60, 2: 25, 3: 10, 4: 5},
        'teacher':   {1: 40, 2: 30, 3: 18, 4: 12},
        'supporter': {1: 75, 2: 20, 3: 5},
    }

    # ---------------- Spending: by school district income ----------------
    # A school district is the school's city and state. Each district gets an
    # income level, written to districts.csv. Each tuple is:
    #   share          fraction of districts at this level (the three add up to 1.0)
    #   income range   the district's median household income, drawn uniformly
    #                  between these two dollar amounts and rounded to $1,000
    #   bargain share  fraction of the district's users who are bargain hunters
    #   price power    tilts which product is picked within a category, with
    #                  weight = price ** power:
    #                    +1  a $8 product is twice as likely as a $4 one (premium)
    #                     0  every product in the category is equally likely
    #                    -1  a $4 product is twice as likely as an $8 one (budget)
    INCOME_LEVELS = {
        #          share  income range ($)     bargain share  price power
        'low':    (0.30, (38_000, 55_000),     0.35,          -1.0),
        'middle': (0.45, (60_000, 90_000),     0.20,           0.0),
        'high':   (0.25, (100_000, 160_000),   0.08,           1.0),
    }
    # Probability that any single purchase is on promotion:
    # 30% for a bargain hunter, 5% for everyone else.
    PROMO_CHANCE = {'bargain_hunter': 0.30, 'other': 0.05}
    # A promotion takes one of these off the list price, each equally likely
    # (10%, 20% or 30% off).
    PROMO_DISCOUNTS = (0.10, 0.20, 0.30)

    # ---------------- Purchases: when ----------------
    # A day's "busyness" = weekend weight x month weight x event multiplier, and a
    # day's chance of being picked is proportional to its busyness.
    # A Saturday or Sunday is 1.4x as busy as a weekday (weekdays count as 1.0).
    WEEKEND_WEIGHT = 1.4
    # Busyness by month, where 1.00 is an ordinary month: a January lull (0.92),
    # a spring fundraising push (March 1.12), a summer dip (June 0.78, July 0.75)
    # and back to school (August 1.12, September 1.15).
    MONTH_WEIGHTS = {1: 0.92, 2: 1.00, 3: 1.12, 4: 1.03, 5: 1.00, 6: 0.78,
                     7: 0.75, 8: 1.12, 9: 1.15, 10: 1.03, 11: 1.08, 12: 0.95}
    # Weights for the hour of day, once the day is picked. Position 0 is
    # midnight to 1am, position 23 is 11pm to midnight. Weekdays peak at lunch
    # (noon, 2.8) and after work (5pm and 6pm, 3.4 and 3.6); weekends peak late
    # morning (11am, 3.6). Nights are close to zero. Signup times use the weekday curve.
    HOUR_WEIGHTS_WEEKDAY = (
        # 0am  1    2     3     4     5    6    7    8    9    10   11
        0.2,  0.1, 0.05, 0.05, 0.05, 0.2, 0.5, 1.0, 1.4, 1.6, 1.8, 2.2,
        # 12pm 1    2    3    4    5    6    7    8    9    10   11
        2.8,  2.4, 1.9, 2.0, 2.6, 3.4, 3.6, 3.0, 2.2, 1.5, 0.9, 0.4)
    HOUR_WEIGHTS_WEEKEND = (
        # 0am  1    2     3     4     5    6    7    8    9    10   11
        0.2,  0.1, 0.05, 0.05, 0.05, 0.1, 0.3, 0.8, 1.6, 2.6, 3.3, 3.6,
        # 12pm 1    2    3    4    5    6    7    8    9    10   11
        3.5,  3.2, 2.9, 2.6, 2.4, 2.3, 2.1, 1.7, 1.2, 0.8, 0.5, 0.3)
    # Holidays and events. Each tuple is:
    #   first day, last day   inclusive dates
    #   demand multiplier     multiplies those days' busyness: 1.15 = 15% busier,
    #                         0.35 = 65% quieter
    #   categories            categories that sell more on those days; their category
    #                         weight is multiplied by EVENT_CATEGORY_BOOST
    CALENDAR_EVENTS = (
        ('2023-01-01', '2023-01-01', 0.60, ()),                       # New Year's Day
        ('2023-02-06', '2023-02-12', 1.15, ('Snacks', 'Beverages')),  # Super Bowl LVII week
        ('2023-04-03', '2023-04-08', 1.08, ('Breakfast', 'Dairy')),   # Easter week
        ('2023-07-04', '2023-07-04', 0.80, ('Snacks', 'Beverages')),  # Independence Day
        ('2023-11-18', '2023-11-22', 1.25, ('Pantry', 'Dairy')),      # Thanksgiving run-up
        ('2023-11-23', '2023-11-23', 0.45, ()),                       # Thanksgiving Day
        ('2023-12-25', '2023-12-25', 0.35, ()),                       # Christmas Day
        ('2024-01-01', '2024-01-01', 0.60, ()),                       # New Year's Day
        ('2024-02-05', '2024-02-11', 1.15, ('Snacks', 'Beverages')),  # Super Bowl LVIII week
        ('2024-03-25', '2024-03-30', 1.08, ('Breakfast', 'Dairy')),   # Easter week
    )
    # An event's categories are 1.6x as likely to be picked on that event's days.
    EVENT_CATEGORY_BOOST = 1.6

    # ---------------- Referrals: who joins through a referral ----------------
    # Chance that a new signup came through a referral. It rises in a straight line
    # from 8% for the first signup to 32% for the last, because there are more
    # users around to refer people as the app grows (viral growth). Halfway through
    # the signup period it is 20%.
    REFERRED_SIGNUP_SHARE = (0.08, 0.32)

    # ---------------- Referrals: who refers ----------------
    # Every user gets a referrer tier. Each tuple is:
    #   organic share   fraction of organic users in the tier (adds up to 1.0)
    #   referred share  the same for users who joined through a referral; they
    #                   refer a bit more, having seen the program work
    #   win weight      how likely this referrer is to be the one who brought in a new
    #                   referred user, relative to a casual referrer (0 = never refers)
    #   invite volume   how many invites that don't convert this tier sends, relative
    #                   to the other tiers (a weight; the total number of invites is n)
    REFERRER_TIERS = {
        #             organic  referred  win weight  invite volume
        'none':      (0.70,    0.60,     0.0,         0.0),
        'casual':    (0.20,    0.25,     1.0,         1.5),
        'active':    (0.08,    0.11,     3.0,         6.0),
        'champion':  (0.02,    0.04,     8.0,        25.0),
    }
    # Teachers reach many parents, so they are 3x as likely to be champions.
    TEACHER_CHAMPION_MULTIPLIER = 3.0
    # Referrers in the same tier don't all send the same number of invites. Each
    # referrer's invite volume is multiplied by a lognormal factor with median 1
    # and this spread (sigma). With 0.6, about two-thirds of referrers land between
    # 0.55x and 1.8x their tier's volume (e^-0.6 and e^+0.6).
    INVITE_VOLUME_SIGMA = 0.6
    # Days after joining before a user can refer anyone (they try the app first):
    # drawn uniformly between 7 and 28.
    REFERRER_READY_DAYS = (7, 28)
    # Enthusiasm fades. When a new user picks their referrer, each candidate's win
    # weight is multiplied by FLOOR + e^(-days since they could start referring / 120).
    # That multiplier is 1.25 on day one, 0.62 after 120 days, 0.30 after a year,
    # and never below 0.25.
    REFERRER_RECENCY_DAYS = 120
    REFERRER_RECENCY_FLOOR = 0.25
    # Chance that a referred user's referrer is from their own school. If nobody at
    # the school can refer yet, someone from another school is used instead.
    SAME_SCHOOL_REFERRAL_SHARE = 0.80

    # ---------------- Referrals: timing ----------------
    # Invites that never convert go out this many days after the referrer can
    # start referring, on average (exponential: most go out in the first couple of
    # months, a few much later).
    INVITE_DELAY_MEAN_DAYS = 60
    # Invites that convert: time from invite to click, then from click to signup.
    # Both are lognormal: half are quicker than the median and a few take much
    # longer. Sigma sets the spread: with sigma 1.0, about two-thirds of clicks
    # happen between 2.2 and 16 hours after the invite (6h x e^-1 and 6h x e^+1).
    CLICK_DELAY_MEDIAN_HOURS = 6.0
    CLICK_DELAY_SIGMA = 1.0
    CLICK_DELAY_MAX_HOURS = 7 * 24        # capped at a week
    SIGNUP_DELAY_MEDIAN_HOURS = 2.0
    SIGNUP_DELAY_SIGMA = 0.9
    # Rules PDF: the referral code must be used within 48 hours of installing the
    # app, so the signup delay is capped just under this.
    ATTRIBUTION_WINDOW_HOURS = 48

    # ---------------- Referrals: invites that don't convert ----------------
    # Chance that an invite that never converts was still clicked, by tier.
    # Personal invites (casual) get clicked more often than mass invites (champion).
    CLICK_RATE_UNCONVERTED = {'casual': 0.42, 'active': 0.37, 'champion': 0.28}
    # 10% of users who joined through a referral had been invited earlier by
    # someone else (an "assist"; credit goes to the invite they actually used).
    MULTI_TOUCH_SHARE = 0.10
    # 4% of invites that never convert go to an address that had already been invited.
    REINVITE_SHARE = 0.04
    # Names and email domains for people who were invited but never joined.
    # Domain weights add up to 100: gmail 40%, yahoo 20%, outlook 15%, icloud 15%, email.com 10%.
    INVITEE_FIRST_NAMES = (
        'Olivia', 'Liam', 'Emma', 'Noah', 'Ava', 'Elijah', 'Sophia', 'Lucas', 'Mia', 'Mateo',
        'Amelia', 'Ethan', 'Harper', 'Aiden', 'Evelyn', 'Kai', 'Aaliyah', 'Diego', 'Priya',
        'Wei', 'Fatima', 'Malik', 'Hannah', 'Grace', 'Omar', 'Zoe', 'Andre', 'Lucia',
    )
    INVITEE_LAST_NAMES = (
        'Nguyen', 'Patel', 'Kim', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson',
        'Martin', 'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Clark', 'Lewis', 'Robinson',
        'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Hill', 'Green',
    )
    INVITEE_EMAIL_DOMAINS = {'gmail.com': 40, 'yahoo.com': 20, 'outlook.com': 15,
                             'icloud.com': 15, 'email.com': 10}

    def __init__(self, seed: int = 42, output_dir: str = "./data"):
        """
        Initialize the data generator.

        Args:
            seed: Random seed for reproducibility
            output_dir: Directory to write output files
        """
        random.seed(seed)
        self.output_dir = output_dir
        self.start_date = datetime(2024, 1, 1)
        self.end_date = datetime(2024, 6, 30)

        # Create output directory if it doesn't exist
        os.makedirs(self.output_dir, exist_ok=True)

        # These will be populated by generate methods
        self.schools = []
        self.users = []
        self.products = []
        self.purchases = []
        self.referrals = []

    def generate_schools(self, n: int = 50) -> List[Dict]:
        """
        Generate school records.

        Args:
            n: Number of schools to generate

        Returns:
            List of school dictionaries
        """
        school_types = ['Elementary', 'Middle', 'High']
        school_names = [
            'Sunnydale', 'Springfield', 'Hawkins', 'Hill Valley', 'Twin Peaks',
            'Weyland', 'Yutani', 'Cyberdyne', 'OCP', 'Tyrell',
            'Wonka', 'Duff', 'Brawndo', 'Slurm', 'Soylent',
            'Rivendell', 'Waterdeep', 'Neverwinter', 'Baldur', 'Ravenloft',
            'Ooo', 'Dungeon', 'Candy Kingdom', 'Fire Kingdom', 'Cloud Kingdom',
            'Arrakis', 'Caladan', 'Giedi Prime', 'Kaitain', 'Ix',
            'Veidt', 'Manhattan', 'Rorschach', 'Comedian', 'Nite Owl'
        ]

        schools = []
        used_combinations = set()

        for i in range(n):
            # Ensure unique school names
            while True:
                name = random.choice(school_names)
                school_type = random.choice(school_types)
                combination = f"{name} {school_type}"
                if combination not in used_combinations:
                    used_combinations.add(combination)
                    break

            school = {
                'school_id': i + 1,
                'name': f"{name} {school_type} School",
                'address': f"{random.randint(100, 9999)} {random.choice(['Main', 'Oak', 'Elm', 'School'])} St",
                'city': random.choice(['Springfield', 'Riverside', 'Madison', 'Georgetown', 'Fairview']),
                'state': random.choice(['CA', 'TX', 'NY', 'FL', 'IL']),
                'zip_code': f"{random.randint(10000, 99999)}",
                'created_at': self.start_date - timedelta(days=random.randint(365, 1825))
            }
            schools.append(school)

        self.schools = schools
        return schools

    def generate_users(self, n: int = 1000) -> List[Dict]:
        """
        Generate user records.

        Args:
            n: Number of users to generate

        Returns:
            List of user dictionaries
        """
        if not self.schools:
            raise ValueError("Schools must be generated before users")

        first_names = [
            'James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer',
            'Michael', 'Linda', 'William', 'Elizabeth', 'David', 'Barbara',
            'Richard', 'Susan', 'Joseph', 'Jessica', 'Thomas', 'Sarah'
        ]
        last_names = [
            'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia',
            'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez'
        ]

        users = []
        for i in range(n):
            first = random.choice(first_names)
            last = random.choice(last_names)

            # User creation dates spread over time
            days_ago = random.randint(0, 365)
            created_at = self.start_date - timedelta(days=days_ago)
            # Time of day follows the weekday app-usage curve instead of midnight.
            created_at += timedelta(hours=random.choices(range(24), self.HOUR_WEIGHTS_WEEKDAY)[0], seconds=random.randint(0, 3599))

            user = {
                'user_id': i + 1,
                'first_name': first,
                'last_name': last,
                'email': f"{first.lower()}.{last.lower()}{random.randint(1, 999)}@email.com",
                'school_id': random.choice(self.schools)['school_id'],
                'created_at': created_at,
                'user_type': random.choices(
                    ['parent', 'teacher', 'supporter'],
                    weights=[0.7, 0.2, 0.1]
                )[0]
            }
            users.append(user)

        self.users = users
        return users

    def generate_products(self, n: int = 100) -> List[Dict]:
        """
        Generate product records.

        Args:
            n: Number of products to generate

        Returns:
            List of product dictionaries
        """
        categories = {
            'Breakfast': ['Cereal', 'Oatmeal', 'Granola Bars', 'Yogurt', 'Waffles'],
            'Snacks': ['Chips', 'Crackers', 'Cookies', 'Pretzels', 'Popcorn', "Plate of Shrimp"],
            'Beverages': ['Juice', 'Water', 'Sports Drink', 'Tea', 'Coffee'],
            'Dairy': ['Milk', 'Cheese', 'Butter', 'Ice Cream', 'Cream Cheese'],
            'Pantry': ['Pasta', 'Rice', 'Soup', 'Sauce', 'Oil']
        }

        brands = [
            'Wonka', 'Duff', 'Buzz Cola', 'Krusty', 'Lard Lad', 'Super Porp',
            'Soylent', 'Brawndo', 'Slurm', 'Bachelor Chow', 'Popplers',
            'Weyland-Yutani', 'Cyberdyne', 'OCP', 'Umbrella', 'Initech',
            'Tyrell Corp', 'Replicant Foods', 'Off-World', 'Shimago-Domínguez', 'Atari',
            'Rekall','CHOAM', 'Bene Gesserit', 'Harkonnen Industries', 'Atreides Organic',
            'Veidt Enterprises', 'Pyramid Deliveries', 'Nostalgia', 'Gunga Diner', 'Gordian Knot'
        ]

        products = []
        product_id = 1

        for category, items in categories.items():
            for item in items:
                for _ in range(n // 25):  # Distribute products across categories
                    product = {
                        'product_id': product_id,
                        'name': f"{random.choice(brands)} {item}",
                        'category': category,
                        'price': round(random.uniform(1.99, 9.99), 2),
                        'points_per_dollar': random.choice([1, 2, 3, 5]),
                        'created_at': self.start_date - timedelta(days=random.randint(30, 365))
                    }
                    products.append(product)
                    product_id += 1

        self.products = products[:n]  # Ensure we have exactly n products
        return self.products

    def generate_purchases(self, n: int = 10000) -> List[Dict]:
        """
        Generate purchase records with realistic patterns.

        Consider:
        - User purchase frequency (some users are more active than others)
        - Time patterns (weekday vs weekend, time of day)
        - Product preferences by user type
        - Seasonal patterns
        - Price sensitivity

        Implementation:
            1. Every user gets an activity segment (heavy, regular, light or
               inactive), which sets how often they buy. From signup, each
               month they may churn (stop buying for good) with their
               segment's monthly churn rate; referred users churn less.
            2. Every user who shops makes a first purchase within a week of
               signing up. The rest are handed out in proportion to each
               user's segment rate times the days they were active.
            3. Each purchase gets a random time while the user was active
               (weekends, busy months and holiday events more likely; hour
               from a daily curve), a category their user type prefers
               (boosted for events, such as snacks in Super Bowl week), a
               product from that category already launched, a quantity, and
               sometimes a promo discount (much more often for bargain
               hunters).

            A user's history starts at signup, which can precede start_date,
            and runs through end_date, so every signup cohort is observable
            from month 0. About DIRTY_DATA_RATE of rows are deliberately
            corrupted; their ids are listed in DQ_MANIFEST_FILENAME.
            docs/data_generation.md documents every assumption.

        Args:
            n: Number of purchases to generate

        Returns:
            List of purchase dictionaries with fields:
                - purchase_id
                - user_id
                - product_id
                - quantity
                - price_paid
                - points_earned
                - purchased_at
                - day_of_week
                - hour_of_day
        """
        if not self.users or not self.products:
            raise ValueError("Users and products must be generated before purchases")

        rng = self._rng('purchases') #set random seed for reproducibility
        referred = set(self._referral_graph()['referred_by']) # People's behaviors change if they were referred, so we need to know who was.
        window_end = self.end_date + timedelta(days=1)  # include all of end_date, instead of stopping at midnight
        first_launch = min(p['created_at'] for p in self.products) #set to the earliest product launch date, so that purchases don't happen before any products exist

        # School district income levels (reference data, saved alongside the other CSVs).
        districts = {(d['city'], d['state']): d for d in self.generate_districts()}
        self.save_to_csv(self.districts, 'districts.csv')
        income_by_school = {s['school_id']: districts[(s['city'], s['state'])]['income_level']
                            for s in self.schools} #Setting income by schools 

        issues = self._split_dirty(n, ('exact_duplicate', 'retry_duplicate', 'orphan_product',
                                       'non_positive_quantity', 'before_signup', 'points_mismatch')) #mixing in deliberate data-quality issues, so the pipeline's quality checks have something to catch
        n_clean = n - issues['exact_duplicate'] - issues['retry_duplicate'] #calculating clean rows

        # 1. Each user: an activity segment (how often they buy) and the period
        #    from signup until they churn or the data ends.
        segments = list(self.ACTIVITY_SEGMENTS)
        shares = [self.ACTIVITY_SEGMENTS[s][0] for s in segments]
        shoppers, weights = [], []
        for user in sorted(self.users, key=lambda u: u['user_id']):
            segment = rng.choices(segments, shares)[0]
            _, _, bargain_share, price_preference = self.INCOME_LEVELS[income_by_school.get(user['school_id'], 'middle')]
            bargain_hunter = rng.random() < bargain_share
            _, rate = self.ACTIVITY_SEGMENTS[segment]
            if rate == 0:
                continue
            monthly_churn = self.MONTHLY_CHURN[segment]#getting monthly churn of the segment
            if user['user_id'] in referred:
                monthly_churn *= self.REFERRED_CHURN_MULTIPLIER
            start = max(user['created_at'], first_launch)
            stop = self._churn_date(rng, start, monthly_churn, window_end)
            if stop <= start:
                continue
            shoppers.append({'user': user, 'start': start, 'stop': stop,
                             'bargain_hunter': bargain_hunter, 'price_preference': price_preference})
            weights.append(rate * (stop - start).total_seconds() / 86400)

        # 2. A first purchase within a week of signup for everyone who shops, then
        #    the rest handed out in proportion to rate x days active.
        catalog = self._catalog_by_category()
        first_week = timedelta(days=self.FIRST_PURCHASE_WITHIN_DAYS)
        lines = [self._make_purchase(rng, s, catalog, s['start'], min(s['start'] + first_week, s['stop']))
                 for s in shoppers[:n_clean]]
        repeat_buyers = rng.choices(shoppers, weights=weights, k=n_clean - len(lines)) if shoppers else []
        lines += [self._make_purchase(rng, s, catalog, s['start'], s['stop']) for s in repeat_buyers]
        if len(lines) < n_clean:
            warnings.warn(f"Only {len(lines)} clean purchases could be generated (asked for {n_clean}).")

        # 3. Deliberate data-quality issues, then ids in time order.
        users_by_id = {u['user_id']: u for u in self.users}
        products_by_id = {p['product_id']: p for p in self.products}
        retry_sources = rng.sample(lines, min(issues['retry_duplicate'], len(lines)))
        for line in retry_sources:
            lines.append(dict(line, _issue='retry_duplicate'))  # client re-upload: new id, same content
        lines.sort(key=lambda r: (r['purchased_at'], r['user_id'], r['product_id'],
                                  r.get('_issue', '')))
        for i, line in enumerate(lines, start=1):
            line['purchase_id'] = i

        # Corrupt rows that are not part of a retry pair, so each row carries one planted issue.
        retry_source_ids = {id(line) for line in retry_sources}
        clean = [r for r in lines if '_issue' not in r and id(r) not in retry_source_ids]
        in_place = [k for k in ('orphan_product', 'non_positive_quantity', 'before_signup',
                                'points_mismatch') for _ in range(issues[k])]
        max_product_id = max(products_by_id)
        for issue, line in zip(in_place, rng.sample(clean, min(len(in_place), len(clean)))):
            line['_issue'] = issue
            if issue == 'orphan_product':
                line['product_id'] = max_product_id + rng.randint(1, 50)
            elif issue == 'non_positive_quantity':
                product = products_by_id[line['product_id']]
                line['quantity'] = rng.choice([0, -1, -2])
                line['price_paid'] = round(product['price'] * line['quantity'], 2)
                line['points_earned'] = self._points(line['price_paid'], product['points_per_dollar'])
            elif issue == 'before_signup':
                signup = users_by_id[line['user_id']]['created_at']
                ts = signup - timedelta(days=rng.randint(1, 30), hours=rng.randint(0, 23),
                                        minutes=rng.randint(0, 59))
                line.update(purchased_at=ts, day_of_week=ts.strftime('%A'), hour_of_day=ts.hour)
            elif issue == 'points_mismatch':
                line['points_earned'] = line['points_earned'] * 2 + 1  # double-points bug

        still_clean = [r for r in clean if '_issue' not in r]
        for line in rng.sample(still_clean, min(issues['exact_duplicate'], len(still_clean))):
            lines.append(dict(line, _issue='exact_duplicate'))  # replayed upload: same id
        lines.sort(key=lambda r: (r['purchase_id'], r.get('_issue') == 'exact_duplicate'))

        injected = {k: [] for k in issues}
        for line in lines:
            issue = line.pop('_issue', None)
            if issue:
                injected[issue].append(line['purchase_id'])
        self._record_dq_injections('purchases', injected)

        fields = ('purchase_id', 'user_id', 'product_id', 'quantity', 'price_paid',
                  'points_earned', 'purchased_at', 'day_of_week', 'hour_of_day')
        self.purchases = [{f: line[f] for f in fields} for line in lines]
        return self.purchases

    def generate_referrals(self, n: int = 1000) -> List[Dict]:
        """
        Generate referral network data.

        Consider:
        - Network effects (some users refer many, most refer none)
        - Conversion rates (not all referrals convert)
        - Time delays between referral and signup
        - Referral chains (referred users can also refer)

        Implementation:
            Who joined through whom comes from _referral_graph(), which is
            shared with generate_purchases(). Every converted row is a real
            signup: referred_user_id is that user, converted_at is their
            created_at, and sent_at precedes it by a click delay plus a signup
            delay inside the 48-hour attribution window. The rest of the n
            attempts are invites that never converted, sent by referrers in
            proportion to how active they are. Invites stop at the last signup
            date, since no later conversion could be represented.
            About DIRTY_DATA_RATE of rows are deliberately corrupted; their ids
            are listed in DQ_MANIFEST_FILENAME.

        Args:
            n: Number of referral attempts to generate

        Returns:
            List of referral dictionaries with fields:
                - referral_id
                - referrer_user_id
                - referred_email
                - referred_user_id (None if not converted)
                - referral_code
                - sent_at
                - converted_at (None if not converted)
                - status (sent, clicked, converted)
        """
        if not self.users:
            raise ValueError("Users must be generated before referrals")

        rng = self._rng('referrals')
        graph = self._referral_graph()
        users = {u['user_id']: u for u in self.users}
        horizon = max(u['created_at'] for u in self.users)
        tier, ready_at, codes = graph['tier'], graph['ready_at'], graph['codes']
        taken_emails = {u['email'].lower() for u in self.users}

        issues = self._split_dirty(n, ('self_referral', 'existing_member_converted', 'duplicate_send',
                                       'status_mismatch', 'converted_before_sent'))
        n_added_dirty = issues['self_referral'] + issues['existing_member_converted'] + issues['duplicate_send']
        conversions = graph['conversions']
        n_multi = int(round(len(conversions) * self.MULTI_TOUCH_SHARE))
        n_unconverted = n - len(conversions) - n_multi - n_added_dirty
        if n_unconverted < 0:
            n_multi, n_unconverted = 0, max(n - len(conversions) - n_added_dirty, 0)
            if len(conversions) + n_added_dirty > n:
                warnings.warn(f"{len(conversions)} users joined via referral, more than n={n}; "
                              "emitting every conversion, so there are more rows than requested.")

        def row(referrer_id, email, sent_at, status, referred_id=None, converted_at=None, issue=None):
            return {'referrer_user_id': referrer_id, 'referred_email': email,
                    'referred_user_id': referred_id, 'referral_code': codes[referrer_id],
                    'sent_at': sent_at.replace(microsecond=0),
                    'converted_at': converted_at.replace(microsecond=0) if converted_at else None,
                    'status': status, '_issue': issue}

        rows = []
        # 1. Converted referrals: one per user who joined through a referral.
        converting = {}
        for referred_id, referrer_id in conversions:
            joined = users[referred_id]['created_at']
            signup_h = min(self._lognormal(rng, self.SIGNUP_DELAY_MEDIAN_HOURS, self.SIGNUP_DELAY_SIGMA),
                           self.ATTRIBUTION_WINDOW_HOURS - 0.5)
            click_h = min(self._lognormal(rng, self.CLICK_DELAY_MEDIAN_HOURS, self.CLICK_DELAY_SIGMA),
                          self.CLICK_DELAY_MAX_HOURS)
            sent_at = joined - timedelta(hours=signup_h + click_h)
            if sent_at < ready_at[referrer_id]:  # referrer only just became eligible
                sent_at = ready_at[referrer_id] + (joined - ready_at[referrer_id]) * rng.uniform(0.2, 0.9)
            converting[referred_id] = row(referrer_id, users[referred_id]['email'], sent_at,
                                          'converted', referred_id, joined)
            rows.append(converting[referred_id])

        # 2. Multi-touch: an earlier, unconverted invite from someone else.
        for referred_id, referrer_id in rng.sample(conversions, min(n_multi, len(conversions))):
            first = converting[referred_id]['sent_at'] - timedelta(days=rng.uniform(3, 30))
            other = self._eligible_referrer(rng, graph, users[referred_id]['school_id'], first,
                                            exclude=referrer_id)
            if other is None:
                n_unconverted += 1
                continue
            rows.append(row(other, users[referred_id]['email'], first,
                            'clicked' if rng.random() < 0.5 else 'sent'))

        # 3. Invites that never converted, weighted by how many each referrer sends.
        senders = [uid for uid, t in tier.items() if t != 'none' and ready_at[uid] < horizon]
        if not senders:
            senders = sorted(users)[:1]
        send_weights = [(self.REFERRER_TIERS[tier[uid]][3] or 1.0)
                        * math.exp(rng.gauss(0, self.INVITE_VOLUME_SIGMA)) for uid in senders]
        invited = []
        for referrer_id in rng.choices(senders, weights=send_weights, k=n_unconverted):
            sent_at = self._invite_time(rng, ready_at[referrer_id], horizon)
            if invited and rng.random() < self.REINVITE_SHARE:
                email = rng.choice(invited)
            else:
                email = self._invitee_email(rng, taken_emails)
                invited.append(email)
            click_rate = self.CLICK_RATE_UNCONVERTED.get(tier[referrer_id], 0.35)
            rows.append(row(referrer_id, email, sent_at, 'clicked' if rng.random() < click_rate else 'sent'))

        # 4. Deliberate data-quality issues.
        for _ in range(issues['self_referral']):
            referrer_id = rng.choice(senders)
            local, domain = users[referrer_id]['email'].split('@', 1)
            email = f"{local}@{domain}" if rng.random() < 0.5 else f"{local}+cc{rng.randint(1, 99)}@{domain}"
            rows.append(row(referrer_id, email, self._invite_time(rng, ready_at[referrer_id], horizon),
                            rng.choice(['sent', 'clicked']), issue='self_referral'))
        members = [u for u in self.users if u['created_at'] <= horizon - timedelta(days=30)]
        for _ in range(issues['existing_member_converted'] if members else 0):
            member = rng.choice(members)
            not_before = member['created_at'] + timedelta(days=30)
            referrer_id = self._eligible_referrer(rng, graph, member['school_id'], horizon,
                                                  exclude=member['user_id'])
            if referrer_id is None:
                continue
            start = max(not_before, ready_at[referrer_id])
            sent_at = start + (horizon - start) * rng.random() if start < horizon else horizon
            rows.append(row(referrer_id, member['email'], sent_at, 'converted', member['user_id'],
                            sent_at + timedelta(hours=rng.uniform(1, 20)), issue='existing_member_converted'))
        unconverted_rows = [r for r in rows if r['status'] != 'converted' and r['_issue'] is None]
        for original in rng.sample(unconverted_rows, min(issues['duplicate_send'], len(unconverted_rows))):
            rows.append(dict(original, sent_at=original['sent_at'] + timedelta(minutes=rng.randint(1, 10)),
                             status='sent', _issue='duplicate_send'))
        for r in rng.sample(unconverted_rows, min(issues['status_mismatch'], len(unconverted_rows))):
            r.update(status='converted', _issue='status_mismatch')  # no user, no converted_at
        converted_rows = [r for r in rows if r['status'] == 'converted' and r['_issue'] is None]
        for r in rng.sample(converted_rows, min(issues['converted_before_sent'], len(converted_rows))):
            r.update(sent_at=r['converted_at'] + timedelta(hours=rng.randint(1, 6)),
                     _issue='converted_before_sent')  # client clock skew

        rows.sort(key=lambda r: (r['sent_at'], r['referrer_user_id'], r['referred_email']))
        injected = {k: [] for k in issues}
        fields = ('referral_id', 'referrer_user_id', 'referred_email', 'referred_user_id',
                  'referral_code', 'sent_at', 'converted_at', 'status')
        referrals = []
        for i, r in enumerate(rows, start=1):
            r['referral_id'] = i
            if r['_issue']:
                injected[r['_issue']].append(i)
            referrals.append({f: r[f] for f in fields})
        self._record_dq_injections('referrals', injected)

        self.referrals = referrals
        return referrals

    # ------------------------------------------------------------------
    # Helpers for generate_purchases() and generate_referrals()
    # ------------------------------------------------------------------

    def _fingerprint(self, salt: str) -> str:
        """Stable summary of the provided entities, used to seed and cache."""
        parts = [salt, str(len(self.schools)), str(len(self.users)), str(len(self.products))]
        if self.users:
            parts += [self.users[0]['email'], self.users[-1]['email'], str(self.users[-1]['created_at'])]
        if self.products:
            parts += [self.products[-1]['name'], str(self.products[-1]['price'])]
        return '|'.join(parts)

    def _rng(self, salt: str) -> random.Random:
        """
        Independent RNG for one generation step.

        Seeded from the users and products the provided methods produced
        (themselves driven by the constructor seed), so output is
        reproducible and does not depend on the order the methods run in.
        """
        return random.Random(self._fingerprint(salt))

    def _referral_graph(self) -> Dict:
        """
        Decide who joined through a referral, who referred them, and each
        user's referral propensity.

        Built once and shared: generate_all() runs generate_purchases() before
        generate_referrals(), but purchase behaviour depends on whether a user
        was referred, so both read this structure.

        Users are processed in signup order. Each new user is referred with a
        probability that ramps up over the signup period; the referrer is
        drawn from users who are already eligible to refer (80% from the same
        school), weighted by tier and by how recently they became eligible.
        Referred users get a referral tier too, so chains form naturally.
        """
        key = self._fingerprint('graph')
        cached = getattr(self, '_referral_graph_cache', None)
        if cached and cached[0] == key:
            return cached[1]

        rng = self._rng('referral-graph')
        ordered = sorted(self.users, key=lambda u: (u['created_at'], u['user_id']))
        t0, t1 = ordered[0]['created_at'], ordered[-1]['created_at']
        span = max((t1 - t0).total_seconds(), 1.0)
        low, high = self.REFERRED_SIGNUP_SHARE
        school_of = {u['user_id']: u['school_id'] for u in ordered}

        tier, ready_at, referred_by = {}, {}, {}
        eligible: Dict[int, List[int]] = {}  # school_id -> users able to refer right now
        waiting: List[Tuple[datetime, int]] = []
        for user in ordered:
            uid, joined = user['user_id'], user['created_at']
            while waiting and waiting[0][0] <= joined:
                _, ready_uid = heapq.heappop(waiting)
                eligible.setdefault(school_of[ready_uid], []).append(ready_uid)

            p_referred = low + (high - low) * (joined - t0).total_seconds() / span
            if eligible and rng.random() < p_referred:
                referrer = self._choose_referrer(rng, user['school_id'], joined, eligible, tier, ready_at)
                if referrer is not None:
                    referred_by[uid] = referrer

            tier[uid] = self._choose_referrer_tier(rng, user, uid in referred_by)
            ready_at[uid] = joined + timedelta(days=rng.uniform(*self.REFERRER_READY_DAYS))
            if self.REFERRER_TIERS[tier[uid]][2] > 0:
                heapq.heappush(waiting, (ready_at[uid], uid))

        # Referral codes: one stable code per potential referrer.
        alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        codes, used = {}, set()
        for user in sorted(self.users, key=lambda u: u['user_id']):
            while True:
                code = f"{user['first_name'].upper()}-{''.join(rng.choice(alphabet) for _ in range(4))}"
                if code not in used:
                    used.add(code)
                    codes[user['user_id']] = code
                    break

        # Potential referrers per school, ordered by when they became eligible.
        by_school: Dict[int, List[Tuple[datetime, int]]] = {}
        for uid, t in tier.items():
            if t != 'none':
                by_school.setdefault(school_of[uid], []).append((ready_at[uid], uid))
        for entries in by_school.values():
            entries.sort()

        graph = {
            'tier': tier,
            'ready_at': ready_at,
            'referred_by': referred_by,
            'codes': codes,
            'referrers_by_school': by_school,
            'conversions': sorted(referred_by.items()),  # (referred user, referrer)
        }
        self._referral_graph_cache = (key, graph)
        return graph

    def _choose_referrer(self, rng: random.Random, school_id: int, at: datetime,
                         eligible: Dict[int, List[int]], tier: Dict[int, str],
                         ready_at: Dict[int, datetime]):
        """Pick who referred a new user: same school 80% of the time."""
        same = eligible.get(school_id) or []
        pool = None
        if same and rng.random() < self.SAME_SCHOOL_REFERRAL_SHARE:
            pool = same
        else:
            others = [s for s, members in eligible.items() if members and s != school_id]
            if others:
                school = rng.choices(others, weights=[len(eligible[s]) for s in others])[0]
                pool = eligible[school]
            elif same:
                pool = same
        if not pool:
            return None
        weights = []
        for uid in pool:
            days_eligible = (at - ready_at[uid]).total_seconds() / 86400
            recency = self.REFERRER_RECENCY_FLOOR + math.exp(-days_eligible / self.REFERRER_RECENCY_DAYS)
            weights.append(self.REFERRER_TIERS[tier[uid]][2] * recency)
        return rng.choices(pool, weights=weights)[0]

    def _choose_referrer_tier(self, rng: random.Random, user: Dict, referred: bool) -> str:
        names = list(self.REFERRER_TIERS)
        weights = [self.REFERRER_TIERS[t][1 if referred else 0] for t in names]
        if user.get('user_type') == 'teacher':
            weights[names.index('champion')] *= self.TEACHER_CHAMPION_MULTIPLIER
        return rng.choices(names, weights=weights)[0]

    def _eligible_referrer(self, rng: random.Random, graph: Dict, school_id: int,
                           at: datetime, exclude: int):
        """A potential referrer who could send an invite at `at`, same school first."""
        for entries in (graph['referrers_by_school'].get(school_id, []), None):
            if entries is None:
                entries = [e for es in graph['referrers_by_school'].values() for e in es]
                entries.sort()
            cutoff = bisect.bisect_right(entries, (at, float('inf')))
            candidates = [uid for _, uid in entries[:cutoff] if uid != exclude]
            if candidates:
                return rng.choice(candidates)
        return None

    def _invite_time(self, rng: random.Random, ready: datetime, horizon: datetime) -> datetime:
        """When an unconverted invite goes out: soon after the referrer became eligible."""
        if ready >= horizon:
            return horizon
        for _ in range(5):
            sent = ready + timedelta(days=rng.expovariate(1 / self.INVITE_DELAY_MEAN_DAYS))
            if sent < horizon:
                return sent
        return ready + (horizon - ready) * rng.random()

    def _invitee_email(self, rng: random.Random, taken: set) -> str:
        """A plausible address for someone who is not (yet) a Carton Caps user."""
        domains = list(self.INVITEE_EMAIL_DOMAINS)
        domain_weights = list(self.INVITEE_EMAIL_DOMAINS.values())
        while True:
            first = rng.choice(self.INVITEE_FIRST_NAMES).lower()
            last = rng.choice(self.INVITEE_LAST_NAMES).lower()
            style = rng.random()
            if style < 0.5:
                local = f"{first}.{last}{rng.randint(1, 99)}"
            elif style < 0.8:
                local = f"{first[0]}{last}{rng.randint(10, 999)}"
            else:
                local = f"{first}{last}{rng.randint(1, 9)}"
            email = f"{local}@{rng.choices(domains, domain_weights)[0]}"
            if email not in taken:
                taken.add(email)
                return email

    def generate_districts(self) -> List[Dict]:
        """
        School districts and their income level: reference data, the way Census
        median household income would be joined to schools. A district is a
        school's city and state. generate_purchases() calls this and writes
        districts.csv, since generate_all() predates it.
        """
        if not self.schools:
            raise ValueError("Schools must be generated before districts")
        rng = self._rng('districts')
        levels = list(self.INCOME_LEVELS)
        shares = [self.INCOME_LEVELS[level][0] for level in levels]
        self.districts = []
        for city, state in sorted({(s['city'], s['state']) for s in self.schools}):
            level = rng.choices(levels, shares)[0]
            low, high = self.INCOME_LEVELS[level][1]
            self.districts.append({
                'district': f'{city}, {state}',
                'city': city,
                'state': state,
                'income_level': level,
                'median_household_income': int(round(rng.uniform(low, high), -3)),
            })
        return self.districts

    @staticmethod
    def _churn_date(rng: random.Random, start: datetime, monthly_churn: float,
                    window_end: datetime) -> datetime:
        """
        When a user stops buying. Every 30 days from start, the user churns with
        probability monthly_churn, at a random point in that month; otherwise they
        carry on to the next month. Users still buying at window_end are cut off there.
        """
        month = timedelta(days=30)
        month_start = start
        while month_start < window_end:
            if rng.random() < monthly_churn:
                return min(month_start + month * rng.random(), window_end)
            month_start += month
        return window_end

    def _catalog_by_category(self) -> Dict[str, Tuple[List[datetime], List[Dict]]]:
        """Products per category (and 'all'), sorted by launch so "on sale at t" is a prefix."""
        groups: Dict[str, List[Dict]] = {'all': list(self.products)}
        for product in self.products:
            groups.setdefault(product['category'], []).append(product)
        catalog = {}
        for category, products in groups.items():
            products = sorted(products, key=lambda p: (p['created_at'], p['product_id']))
            catalog[category] = ([p['created_at'] for p in products], products)
        return catalog

    def _event_on(self, day) -> Tuple[float, Tuple[str, ...]]:
        """Demand multiplier and boosted categories for a calendar day (1.0 and none if no event)."""
        iso = day.strftime('%Y-%m-%d')
        for first, last, multiplier, categories in self.CALENDAR_EVENTS:
            if first <= iso <= last:
                return multiplier, categories
        return 1.0, ()

    def _purchase_time(self, rng: random.Random, start: datetime, stop: datetime) -> datetime:
        """
        A random moment between start and stop. Busier days are more likely
        (weekends, seasonal months, holiday events), and the hour follows the
        daily shopping curve.
        """
        span = stop - start
        busiest = (self.WEEKEND_WEIGHT * max(self.MONTH_WEIGHTS.values())
                   * max([1.0] + [e[2] for e in self.CALENDAR_EVENTS]))
        while True:  # keep a random day with probability proportional to how busy it is
            day = start + span * rng.random()
            busy = ((self.WEEKEND_WEIGHT if day.weekday() >= 5 else 1.0)
                    * self.MONTH_WEIGHTS[day.month] * self._event_on(day)[0])
            if rng.random() * busiest <= busy:
                break
        hours = self.HOUR_WEIGHTS_WEEKEND if day.weekday() >= 5 else self.HOUR_WEIGHTS_WEEKDAY
        ts = datetime(day.year, day.month, day.day, rng.choices(range(24), hours)[0],
                      rng.randrange(60), rng.randrange(60))
        if not start <= ts < stop:  # the hour fell outside the active period on its first or last day
            ts = (start + span * rng.random()).replace(microsecond=0)
        return ts

    def _make_purchase(self, rng: random.Random, shopper: Dict, catalog: Dict,
                       start: datetime, stop: datetime) -> Dict:
        """One purchase between start and stop: when, which product, how many, and at what price."""
        user = shopper['user']
        ts = self._purchase_time(rng, start, stop)
        preferences = dict(self.CATEGORY_PREFERENCES.get(user['user_type'], self.CATEGORY_PREFERENCES['parent']))
        for boosted in self._event_on(ts)[1]:  # e.g. snacks in Super Bowl week
            preferences[boosted] = preferences.get(boosted, 1.0) * self.EVENT_CATEGORY_BOOST
        category = rng.choices(list(preferences), list(preferences.values()))[0]
        launched, products = catalog.get(category, catalog['all'])
        on_sale = products[:bisect.bisect_right(launched, ts)]
        if not on_sale:  # nothing launched in this category yet: any product on sale
            launched, products = catalog['all']
            on_sale = products[:bisect.bisect_right(launched, ts)]
        # District income: pricier products are likelier in richer districts, cheaper ones in poorer.
        preference = shopper['price_preference']
        product = rng.choices(on_sale, [p['price'] ** preference for p in on_sale])[0]
        # User type: how many units per purchase.
        quantities = self.QUANTITY_WEIGHTS.get(user['user_type'], self.QUANTITY_WEIGHTS['parent'])
        quantity = rng.choices(list(quantities), list(quantities.values()))[0]
        promo_chance = self.PROMO_CHANCE['bargain_hunter' if shopper['bargain_hunter'] else 'other']
        discount = rng.choice(self.PROMO_DISCOUNTS) if rng.random() < promo_chance else 0.0
        price_paid = round(product['price'] * quantity * (1 - discount), 2)
        return {
            'purchase_id': None,
            'user_id': user['user_id'],
            'product_id': product['product_id'],
            'quantity': quantity,
            'price_paid': price_paid,
            'points_earned': self._points(price_paid, product['points_per_dollar']),
            'purchased_at': ts,
            'day_of_week': ts.strftime('%A'),
            'hour_of_day': ts.hour,
        }

    @staticmethod
    def _points(price_paid: float, points_per_dollar: int) -> int:
        """Business rule: floor(price_paid x points_per_dollar); 100 points = $1 to the school."""
        return int(math.floor(round(price_paid * points_per_dollar, 6)))

    @staticmethod
    def _lognormal(rng: random.Random, median: float, sigma: float) -> float:
        return median * math.exp(rng.gauss(0, sigma))

    def _split_dirty(self, n: int, issues: Tuple[str, ...]) -> Dict[str, int]:
        """How many rows of each issue type to inject (at least two of each when enabled)."""
        if self.DIRTY_DATA_RATE <= 0 or n <= 0:
            return {issue: 0 for issue in issues}
        total = min(max(int(round(n * self.DIRTY_DATA_RATE)), 2 * len(issues)), n // 10)
        base, extra = divmod(total, len(issues))
        return {issue: base + (1 if i < extra else 0) for i, issue in enumerate(issues)}

    def _record_dq_injections(self, dataset: str, injected: Dict[str, List[int]]) -> None:
        """Write the ids of every deliberately corrupted row, as a test oracle for the pipeline."""
        log = getattr(self, '_dq_injections', None) or {}
        log[dataset] = {issue: sorted(set(ids)) for issue, ids in injected.items()}
        self._dq_injections = log
        manifest = {
            'note': 'Rows deliberately corrupted by data_generator.py. Not an input to the pipeline; '
                    'tests use it to check the data-quality layer catches every planted issue.',
            'dirty_data_rate': self.DIRTY_DATA_RATE,
            'datasets': log,
        }
        with open(os.path.join(self.output_dir, self.DQ_MANIFEST_FILENAME), 'w') as f:
            json.dump(manifest, f, indent=2)

    def save_to_csv(self, data: List[Dict], filename: str) -> None:
        """
        Save data to CSV file.

        Args:
            data: List of dictionaries to save
            filename: Output filename (without path)
        """
        if not data:
            print(f"Warning: No data to save for {filename}")
            return

        filepath = os.path.join(self.output_dir, filename)

        with open(filepath, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=data[0].keys())
            writer.writeheader()
            writer.writerows(data)

        print(f"Saved {len(data)} records to {filepath}")

    def save_to_sqlite(self, db_path: str | None = None) -> None:
        """
        Save all generated data to SQLite database.

        Args:
            db_path: Path to SQLite database file
        """
        if db_path is None:
            db_path = os.path.join(self.output_dir, "carton_caps_generated.db")

        conn = sqlite3.connect(db_path)

        # Helper function to create table from data
        def create_and_insert(table_name: str, data: List[Dict]):
            if not data:
                return

            # Create table based on first record
            columns = []
            for key, value in data[0].items():
                if isinstance(value, int):
                    col_type = "INTEGER"
                elif isinstance(value, float):
                    col_type = "REAL"
                elif isinstance(value, datetime):
                    col_type = "TIMESTAMP"
                else:
                    col_type = "TEXT"
                columns.append(f"{key} {col_type}")

            create_sql = f"CREATE TABLE IF NOT EXISTS {table_name} ({', '.join(columns)})"
            conn.execute(create_sql)

            # Insert data
            placeholders = ', '.join(['?' for _ in data[0].keys()])
            insert_sql = f"INSERT INTO {table_name} VALUES ({placeholders})"

            for record in data:
                values = [record[key] for key in data[0].keys()]
                conn.execute(insert_sql, values)

        # Create and populate tables
        create_and_insert('schools', self.schools)
        create_and_insert('users', self.users)
        create_and_insert('products', self.products)
        create_and_insert('purchases', self.purchases)
        create_and_insert('referrals', self.referrals)

        conn.commit()
        conn.close()

        print(f"Saved all data to {db_path}")

    def generate_all(self,
                     n_schools: int = 50,
                     n_users: int = 1000,
                     n_products: int = 100,
                     n_purchases: int = 10000,
                     n_referrals: int = 1000) -> None:
        """
        Generate all datasets and save to files.

        Args:
            n_schools: Number of schools
            n_users: Number of users
            n_products: Number of products
            n_purchases: Number of purchases
            n_referrals: Number of referral attempts
        """
        print("Generating Carton Caps data...")
        print("-" * 40)

        # Generate data in order (dependencies matter)
        print(f"Generating {n_schools} schools...")
        self.generate_schools(n_schools)
        self.save_to_csv(self.schools, 'schools.csv')

        print(f"Generating {n_users} users...")
        self.generate_users(n_users)
        self.save_to_csv(self.users, 'users.csv')

        print(f"Generating {n_products} products...")
        self.generate_products(n_products)
        self.save_to_csv(self.products, 'products.csv')

        print(f"Generating {n_purchases} purchases...")
        try:
            self.generate_purchases(n_purchases)
            self.save_to_csv(self.purchases, 'purchases.csv')
        except NotImplementedError as e:
            print(f"Skipping purchases: {e}")

        print(f"Generating {n_referrals} referrals...")
        try:
            self.generate_referrals(n_referrals)
            self.save_to_csv(self.referrals, 'referrals.csv')
        except NotImplementedError as e:
            print(f"Skipping referrals: {e}")

        # Also save to SQLite for convenience
        print("\nSaving to SQLite database...")
        self.save_to_sqlite()

        print("-" * 40)
        print("Data generation complete!")


if __name__ == "__main__":
    # Initialize generator
    generator = CartonCapsDataGenerator()

    # Generate all datasets
    generator.generate_all(
        n_schools=50,
        n_users=1000,
        n_products=100,
        n_purchases=10000,
        n_referrals=1000
    )

    print("\nNext steps:")
    print("1. Implement the generate_purchases() method")
    print("2. Implement the generate_referrals() method")
    print("3. Re-run this script to generate complete datasets")
    print("4. Build your analytics pipeline using the generated data")
