# Data generation

`data_generator.py` is the provided generator with `generate_purchases()` and `generate_referrals()` implemented, plus a small `generate_districts()` for school-district income. The provided code has two small fixes: `generate_users` gives each signup a time of day instead of midnight (see [Timeline](#timeline)), and `save_to_csv` writes UTF-8 on every platform (see [Known issues in the provided code](#known-issues-in-the-provided-code)). Apart from those, the diff against the original only removes the two `NotImplementedError` stubs and adds code.

Every number that drives the behaviour lives in [`generator_settings.json`](../generator_settings.json), grouped by topic (`data_quality`, `purchases`, `districts`, `calendar`, `referrals`), each with a description of what it means. The generator reads the file once, when it is imported, and checks it: shares must add up to 1 and probabilities must be between 0 and 1, or it stops with a message naming the setting. To try other values without editing the file, point `CARTON_CAPS_GENERATOR_SETTINGS` at a copy. This document refers to settings by their path in the file, such as `purchases.monthly_churn`. It explains the math behind those numbers from the ground up, then walks through how purchases, spending and referrals are generated.

```bash
python data_generator.py          # writes ./data/*.csv (including districts.csv) and ./data/carton_caps_generated.db
python -m pytest tests/test_data_generator.py
```

## Source schema

The pipeline treats the generator's output as the source contract, not the schema in `Carton_Caps_Data.sqlite`. The provided database can't support the required analytics by itself. It has no points (so no fundraising dollars), no product categories, no user types and no referrals table.

| Provided `Carton_Caps_Data.sqlite` | Generator output | Difference |
|---|---|---|
| `Schools(id, name, address, created_at)`, 7 rows | `schools(school_id, name, address, city, state, zip_code, created_at)` | Address split into parts |
| `Users(id, school_id, name, email UNIQUE, created_at)`, 34 rows | `users(user_id, first_name, last_name, email, school_id, created_at, user_type)` | Adds `user_type`; email is not guaranteed unique (see below) |
| `Products(id, name, description, price, created_at)`, 10 rows | `products(product_id, name, category, price, points_per_dollar, created_at)` | Adds `category` and `points_per_dollar`; no description |
| `Purchase_History(id, user_id, product_id, quantity, purchased_at)`, empty | `purchases(..., price_paid, points_earned, day_of_week, hour_of_day)` | Adds amounts and points |
| none | `referrals` | New |
| none | `districts(district, city, state, income_level, median_household_income)` | New reference data: income by school district |
| `Conversation_History`, 484 chatbot messages from 34 users over two hours on 2025-04-03 | none | Not generated. Its ids and dates don't line up with the generated data, so it is listed as a future source in the pipeline spec |

`districts.csv` is written by `generate_purchases()`, because the provided `generate_all()` doesn't know about it. The provided `save_to_sqlite()` doesn't include it either; the pipeline reads the CSVs.

## Timeline

The provided generators build the user base and catalog before the configured `start_date`–`end_date` window (H1 2024). `generate_users` computes `created_at = start_date - 0..365 days`, and `generate_products` puts every launch 30–365 days before `start_date`. That design is kept as provided. The provided code subtracted whole days from a midnight date, so every signup happened at exactly 00:00:00. One added line gives each signup a time of day:

```python
created_at = self.start_date - timedelta(days=days_ago)   # as provided
created_at += timedelta(hours=random.choices(range(24), self.HOUR_WEIGHTS_WEEKDAY)[0], seconds=random.randint(0, 3599))   # added
```

The resulting timeline:

- **Signups run from 2023-01-01 to 2024-01-01** (four users join on Jan 1, 2024, when `days_ago` is 0). Signup times follow the weekday hour curve, peaking at lunchtime and 5–7pm.
- **Product launches run from 2023-01-01 to 2023-12-02.** A product can only be bought on or after its launch date, so the catalog fills out over 2023.
- **Purchases start at each user's signup and run through the end of `end_date`**, 18 months in all. Each signup cohort is then observable from month 0, and January–June 2024 shows the established user base.
- **Referral conversions are real signups**, so they happen in 2023 (plus Jan 1, 2024). No invites are sent after the last signup, since none could convert: the rules require referred users to be new.
- **January–June 2024 has no new users and no referral activity.** Monthly active users peak in December 2023 and decline through 2024 as users stop buying. That comes from the provided user generator, not from the behaviour model.

## The math, from the ground up

Everything the generator does is built from a handful of ideas. This section explains each one, with examples taken from the actual settings.

### Random numbers and seeds

A computer's "random" numbers come from a formula that produces a long sequence of numbers that look random. The sequence is fixed by its starting point, called the **seed**: the same seed always gives the same sequence. The provided generator seeds with 42, so every run produces exactly the same data, which makes it reproducible and testable.

Each step (purchases, referrals, districts) has its own sequence, seeded from the users and products that the provided code generated. That means the order in which the methods run doesn't change the output.

The basic building block is `rng.random()`: a number between 0 and 1 where every value is equally likely. Everything else is built from it.

### What a probability distribution is

A **probability distribution** describes how likely each possible outcome is. Rolling a die has six outcomes, each with probability 1/6. Some useful vocabulary:

- **Discrete** distributions have separate outcomes you can list: a quantity of 1, 2, 3 or 4, or a user type.
- **Continuous** distributions can take any value in a range, such as a number of days or hours.
- The **mean** is the average outcome over many draws.
- The **median** is the middle outcome: half of draws are below it and half above.
- A distribution is **skewed** when one side has a long tail. For a waiting time, most waits are short but a few are very long, so the mean ends up larger than the median.

The generator uses six distributions, described below.

### 1. Uniform: every value equally likely

A uniform distribution gives every value in a range the same chance. `rng.uniform(a, b)` picks any number between `a` and `b`; `rng.choice(options)` picks one item from a list with equal odds.

Where it's used:
- A district's median household income is uniform within its level's range. A "middle" district is equally likely to land anywhere from $60,000 to $90,000.
- A promotion's discount is 10%, 20% or 30% with equal odds (`purchases.promo_discounts`).
- The first purchase falls at a uniformly random moment in the user's first 7 days (`purchases.first_purchase_within_days`).
- A user can start referring a uniform 7–28 days after joining (`referrals.referrer_ready_days`).

### 2. Weighted choice: some options more likely than others

A weighted choice (formally a **categorical** distribution) picks one option from a list where each option has a **weight**. The chance of an option is its weight divided by the total of all the weights:

```
P(option) = weight of option / sum of all weights
```

Only the ratios between weights matter. `{1: 60, 2: 25}` and `{1: 12, 2: 5}` behave the same, because in both a 1 is 2.4 times as likely as a 2.

Worked example (`purchases.quantity_weights` for a teacher, `{"1": 40, "2": 30, "3": 18, "4": 12}`): the total is 100, so a teacher buys 1 unit 40% of the time, 2 units 30%, 3 units 18% and 4 units 12%. The average is 1×0.40 + 2×0.30 + 3×0.18 + 4×0.12 = **2.02 units**. For a supporter (`{"1": 75, "2": 20, "3": 5}`) it is 1.30 units.

Worked example (`purchases.category_preferences` for a parent): the weights 1.4 + 1.3 + 0.9 + 1.2 + 0.9 add up to 5.7, so a parent picks Breakfast 1.4 / 5.7 = 25% of the time and Pantry 0.9 / 5.7 = 16%.

In code this is `rng.choices(options, weights)`. It's used for activity segments, categories, quantities, the hour of the day, district income levels, referrer tiers and email domains.

### 3. Yes or no with a set probability

The simplest distribution (a **Bernoulli** trial) answers yes or no: "yes" with probability `p`, "no" otherwise. The code draws `rng.random()` (uniform between 0 and 1) and checks whether it is below `p`. Since the draw is below 0.30 exactly 30% of the time, `rng.random() < 0.30` is "yes" 30% of the time.

Where it's used:
- Is this user a bargain hunter? Yes for 35% of users in low-income districts, 20% in middle, 8% in high (`districts.income_levels`, `bargain_hunter_share`).
- Is this purchase on promotion? 30% for a bargain hunter, 5% for everyone else (`purchases.promo_chance`).
- Did this new user join through a referral? See the ramp below.
- Was this unconverted invite clicked? 42% for casual referrers (`referrals.click_rate_unconverted`).

### 4. Monthly churn: a yes/no check every month

**Churn** is a user stopping for good. The generator models it as one yes/no check per month: every 30 days after signup, a user who is still buying stops with their segment's monthly churn probability `p` (at a random point in that month), and otherwise carries on. The number of months a user lasts this way follows a **geometric** distribution. Its properties:

- The chance of still buying after `k` months is `(1 − p)^k`, because the user has to pass `k` checks in a row.
- The average lifetime is `1 / p` months.
- Each month, the same share of the remaining users leaves. That's a constant churn rate, which is what "X% monthly churn" means in business reporting.

The rates (`purchases.monthly_churn`), with referred users churning 25% less (`purchases.referred_churn_multiplier` = 0.75):

| Segment | Monthly churn | Still buying after 6 months | After 12 months | Average lifetime | Referred users' monthly churn |
|---|---|---|---|---|---|
| Heavy | 2% | 0.98^6 = 89% | 0.98^12 = 78% | 50 months | 1.5% |
| Regular | 4% | 78% | 61% | 25 months | 3% |
| Light | 8% | 61% | 37% | 12.5 months | 6% |

Why these numbers: consumer subscription businesses typically lose 5–10% of customers a month (about 6.5% on average for B2C), replenishment products such as groceries lose under 4%, and the best businesses stay under 3% ([Mean CEO subscription benchmarks](https://blog.mean.ceo/?p=10240)). Light users churn like a typical consumer product and heavy users like the best. Across all buyers, the blend is about 6% a month. Users still buying on June 30, 2024 are cut off there; they haven't churned, the data simply ends.

Churn isn't the only reason a user can be missing from a month. A light user who hasn't churned can still go a month without buying, because they buy rarely. Monthly retention in the pipeline reflects both.

### 5. Exponential: waiting times

The **exponential** distribution is the continuous version of the same idea: a waiting time when the event is equally likely at any moment. It has one setting, the mean.

- Short waits are most common and long waits steadily rarer. The distribution is skewed, with a long right tail.
- The median is about 0.69 × the mean (precisely mean × ln 2).
- The chance of waiting longer than `t` is `e^(-t / mean)`. 37% of waits are longer than the mean, and 13.5% more than twice the mean.

Used for when an invite that never converts goes out: on average 60 days after the referrer can start referring (`referrals.invite_delay_mean_days`). The median is 42 days, and 13.5% go out more than 120 days later. In code: `rng.expovariate(1 / mean)`.

### 6. Normal and lognormal: "usually about this, occasionally much more"

The **normal** distribution is the familiar bell curve. It is symmetric around its mean, and its spread is measured by the **standard deviation**, sigma (σ). About 68% of values fall within 1 sigma of the mean, and 95% within 2 sigma. In code it is `rng.gauss(0, sigma)`.

The **lognormal** distribution is what you get by putting a normal draw into an exponent: `median × e^(normal draw)`. Because of the exponent, the bell curve becomes a skewed curve: values cluster around the median, can never go below zero, and occasionally run many times larger than the median. Response times and how much people do things often look like this.

Reading the settings: with median `m` and spread `σ`, about two-thirds of values fall between `m × e^-σ` and `m × e^+σ`, and about 2.5% are above `m × e^(2σ)`.

Worked example (`referrals.click_delay`: `median_hours` = 6, `sigma` = 1.0): half of the people who click do so within 6 hours of the invite. Two-thirds click between 2.2 hours (6 × e^-1) and 16 hours (6 × e^+1). About 2.5% take more than 42 hours. The delay is capped at a week.

Also used for:
- Signup after a click: median 2 hours, sigma 0.9, capped just under the rules' 48-hour window.
- Spread in invite volume within a referrer tier: median 1×, sigma 0.6, so two-thirds of referrers send between 0.55× and 1.8× their tier's typical volume.

### Handing out a fixed number of purchases

The generator has to produce exactly `n` purchases (10,000 by default) and decide which users make them. It does this with repeated weighted choice. Each purchase picks a user, with every user's weight being:

```
weight = segment rate × days active
```

A user's expected number of purchases is then `n × (their weight / total of all weights)`. Repeating a weighted choice a fixed number of times like this is called a **multinomial** draw.

Worked example with three users and 100 purchases to hand out:

| User | Segment rate | Days active | Weight | Share of weight | Expected purchases |
|---|---|---|---|---|---|
| A | heavy, 8 | 200 | 1,600 | 1,600 / 2,060 = 78% | 78 |
| B | regular, 3 | 120 | 360 | 17% | 17 |
| C | light, 1 | 100 | 100 | 5% | 5 |

Before this step, every user who buys gets one purchase at a random moment in their first week. The multinomial draw hands out the rest.

### Picking busier days more often

A purchase needs a date. Some days should be likelier than others: weekends, busy months and holiday events. Each day gets a **busyness** score:

```
busyness = weekend weight (1.4 or 1.0) × month weight × event multiplier
```

To pick a day in proportion to busyness, the generator uses **rejection sampling**:

1. Pick a moment uniformly at random within the user's active period.
2. Keep it with probability `busyness / highest possible busyness`; otherwise go back to step 1.

The "highest possible busyness" is the most any day could score: weekend (1.4) × busiest month (1.15) × biggest event (1.25) = 2.01. Worked example: a Saturday in September (1.4 × 1.15 = 1.61) is kept 1.61 / 2.01 = 80% of the time, and a Tuesday in July (1.0 × 0.75 = 0.75) only 37% of the time. Over many draws, that Saturday is picked 1.61 / 0.75 = 2.1 times as often as the Tuesday, exactly the ratio of their busyness.

Once the day is chosen, the hour is a weighted choice from `calendar.hour_weights_weekday` or `calendar.hour_weights_weekend`.

### Turning price into a preference

Within a category, the product is a weighted choice where each product's weight is its price raised to a power, `price ** power`, with the power set by the district's income (`districts.income_levels`, `price_power`):

| Power | Weight of a $4 product | Weight of an $8 product | Effect |
|---|---|---|---|
| +1 (high income) | 4 | 8 | the $8 product is twice as likely |
| 0 (middle income) | 1 | 1 | every product equally likely (anything to the power 0 is 1) |
| -1 (low income) | 1/4 | 1/8 | the $4 product is twice as likely |

### Combining effects by multiplying

When several things make an outcome more likely, their effects are multiplied. Busyness is weekend × month × event. During Super Bowl week, the weights for Snacks and Beverages are multiplied by 1.6 (`calendar.event_category_boost`). Multiplying keeps each setting's meaning simple: 1.0 means "no effect", 1.4 means "40% more" and 0.75 means "25% less", and they combine without interfering with each other.

### Straight-line ramps

The chance that a new signup came through a referral grows over time, from 8% for the first signup to 32% for the last (`referrals.referred_signup_share`). In between, it is a straight line (**linear interpolation**):

```
p = 8% + (32% - 8%) × (fraction of the signup period that has passed)
```

Halfway through the year, p = 8% + 24% × 0.5 = 20%.

### Why a few users make most purchases

The challenge asks for a power-law-like pattern, where a small group makes most of the purchases. It emerges from multiplying two sources of variety:
- Purchase rates differ 8-to-1 between heavy and light users.
- How long users keep buying differs too: heavy users churn 2% a month and light users 8%, so some users stay many times longer than others.

A heavy user who buys for all 18 months (weight 8 × about 540 days) carries over 70 times the weight of a light user who churns after two months (1 × 60 days). In the default run, the top 10% of users make 42% of all purchases and 17% make none.

## Purchases, step by step

1. **Segment and churn.** Each user is assigned an activity segment by weighted choice, which sets how often they buy. From signup, a monthly yes/no check decides when they churn (the monthly churn section above). Purchases can only happen between signup and churn, and never after `end_date`.

   | Segment | Share of users | Purchase rate (vs a light user) | Monthly churn (referred users) |
   |---|---|---|---|
   | Heavy | 10% | 8 | 2% (1.5%) |
   | Regular | 30% | 3 | 4% (3%) |
   | Light | 45% | 1 | 8% (6%) |
   | Inactive | 15% | 0, never buys | n/a |

2. **First purchase.** Everyone who buys makes a first purchase within 7 days of signing up. For a referred user, that is the qualifying action that earns the referral bonus.
3. **The rest.** The remaining purchases are handed out by weighted choice, with weight = rate × days active (the multinomial draw above).
4. **When.** A moment in the allowed period, picked in proportion to busyness, then an hour from the daily curve. If that hour falls before the signup time or after the active period ends, a uniformly random moment within the period is used instead.
5. **Which product.** First a category by weighted choice from the user type's preferences (boosted for events), then a product in that category already launched by that moment, weighted by price to the district's power. If no product in that category has launched yet, any launched product is used.
6. **How many and at what price.** A quantity by weighted choice for the user type. A yes/no draw for whether it's on promotion, and if so a uniform choice of 10%, 20% or 30% off. `price_paid = list price × quantity × (1 − discount)`, rounded to the cent, and `points_earned = floor(price_paid × points_per_dollar)`.

**Time settings in detail.**
- Weekends: 1.4× a weekday.
- Months: January 0.92, February 1.00, March 1.12, April 1.03, May 1.00, June 0.78, July 0.75, August 1.12, September 1.15, October 1.03, November 1.08, December 0.95.
- Events: Super Bowl week ×1.15, with Snacks and Beverages boosted. Thanksgiving run-up ×1.25, with Pantry and Dairy. Easter week ×1.08, with Breakfast and Dairy. Independence Day ×0.80. Thanksgiving Day ×0.45, Christmas Day ×0.35, New Year's Day ×0.60.

In the default run, Super Bowl week 2024 averages 28 purchases a day against 21 in late January, with Snacks and Beverages 61% of its purchases against 43% in the surrounding weeks. Thanksgiving Day has 9 purchases and Christmas Day 13, against about 25 on an ordinary early-December day.

## Spending by user type and district income

Two things change how much a purchase is worth.

**User type sets the quantity.** Teachers stock classrooms, so they buy more units at a time; supporters (grandparents, neighbours) mostly buy one item.

| User type | Quantity weights (1 / 2 / 3 / 4 units) | Average units |
|---|---|---|
| Teacher | 40 / 30 / 18 / 12 | 2.0 |
| Parent | 60 / 25 / 10 / 5 | 1.6 |
| Supporter | 75 / 20 / 5 / 0 | 1.3 |

**District income sets which products and how often a promotion is used.** A school district is the school's city and state. `generate_districts()` gives each district an income level by weighted choice, then a median household income drawn uniformly in that level's range. That stands in for external data such as the Census median household income for the area.

| Income level | Share of districts | Median household income | Bargain hunters | Price power |
|---|---|---|---|---|
| Low | 30% | $38,000–$55,000 | 35% of users | -1, leans to cheaper products |
| Middle | 45% | $60,000–$90,000 | 20% | 0, no lean |
| High | 25% | $100,000–$160,000 | 8% | +1, leans to pricier products |

The default run has 21 districts: 6 low (19 schools), 10 middle (23 schools) and 5 high (8 schools). The effects show up clearly in the purchases:

| Income level | Average list price per unit | Average spend per purchase | Purchases on promotion |
|---|---|---|---|
| Low | $4.68 | $7.44 | 15% |
| Middle | $5.68 | $9.24 | 9% |
| High | $6.89 | $11.20 | 7% |

By user type, spend per purchase averages $6.67 for supporters, $8.63 for parents and $11.01 for teachers.

## Referral network

**Who joins through a referral.** Users are processed in signup order. Each new user is referred with a probability that ramps from 8% to 32% across the signup period (the straight-line ramp above). Overall, 17% of users joined through a referral; by quarter of 2023 that's 9%, 13%, 21% and 27%.

**Who refers.** Each user gets a referrer tier by weighted choice:

| Tier | Share of organic users | Share of referred users | Win weight | Invite volume |
|---|---|---|---|---|
| None | 70% | 60% | 0 | 0 |
| Casual | 20% | 25% | 1 | 1.5 |
| Active | 8% | 11% | 3 | 6 |
| Champion | 2% (6% of teachers) | 4% | 8 | 25 |

- *Win weight* is how likely a referrer is to be the one who brought in a new user (a weighted choice among everyone who can refer at that moment).
- *Invite volume* is a weight for how many invites that don't convert a tier sends. Each referrer's volume is also multiplied by a lognormal factor (sigma 0.6), so referrers in the same tier differ.

Users can start referring 7–28 days after joining. Enthusiasm fades: a candidate's win weight is multiplied by `0.25 + e^(-days since they could start / 120)`, which is 1.25 on day one, 0.62 after 120 days and 0.30 after a year. 80% of the time the referrer comes from the new user's own school, falling back to another school when nobody there can refer yet; the realised same-school share is 70%.

**Funnel and timing.**
- Every converted row is a real signup. `referred_user_id` is that user, `converted_at` is their `created_at`, and `referred_email` is their email.
- `sent_at` precedes the signup by a lognormal click delay (median 6 hours, sigma 1.0, capped at a week) plus a lognormal signup delay (median 2 hours, sigma 0.9, capped inside the 48-hour attribution window).
- Invites that never convert go out an exponential number of days after the referrer can start referring (mean 60). They were clicked 42% of the time from casual referrers, 37% from active and 28% from champions.
- Mass invites convert far worse than personal ones. Referrers who sent 10 or more invites converted 7% of them, against 21% for those who sent 1–2 and 25% for those who sent 3–9.
- Invites sent in December 2023 convert at only 10%, because nobody signs up after Jan 1, 2024.

**Chains and multi-touch.** Referred users get a referrer tier too, so chains form naturally: 4 levels deep at the default scale and 6 at 10x. 10% of converted users had first been invited by someone else (an assist; credit goes to the converting invite). 4% of unconverted invites go to an address that had already been invited.

## Business rules inferred or created

| Rule | Source |
|---|---|
| `price_paid` is the line total after any promo discount | Assumed (the docstring doesn't define it) |
| `points_earned = floor(price_paid × points_per_dollar)` | Assumed |
| 100 points = $1 donated to the user's school, so schools receive 1–5% of spend | Assumed; used for all fundraising metrics |
| Each referrer has one stable referral code | Rules PDF: "a unique referral code" |
| Referred users must be new, and self-referrals (same email, including plus-addressing) are invalid | Rules PDF |
| Signup must happen within 48 hours of clicking the invite | Rules PDF (48 hours after install) |
| The qualifying action for the bonus is the referred user's first purchase scan | Rules PDF lists "first eligible product scan or links to a school". Every generated user already has a school, so the scan is the trigger |
| $5 bonus each to referrer and referred user, credited as school donations, earned on the qualifying scan | Rules PDF; calculated in the pipeline, not generated |
| A user must be a member for at least 7 days before referring | Assumed (stands in for "verified account") |
| When several invites reach the same person, the converting invite gets the credit | Assumed (last-touch attribution) |
| A school district is the school's city and state | Assumed (the generated schools have no district field) |

## Deliberately injected data-quality issues

About 1% of rows (`data_quality.dirty_data_rate` = 0.01, with at least two of each type) are corrupted so the pipeline's data-quality layer has real problems to catch. The id of every corrupted row is written to `data/injected_dq_issues.json`. The pipeline never reads that file; tests use it to check that every planted issue is detected. Set it to 0 for a clean dataset (or `gen.DIRTY_DATA_RATE = 0` on one generator instance, as the tests do).

| Dataset | Issue | Rows (default) | What it simulates |
|---|---|---|---|
| purchases | `exact_duplicate` | 17 | The same upload replayed: identical row, same `purchase_id` |
| purchases | `retry_duplicate` | 17 | A client retry: same user, product and timestamp, new `purchase_id` |
| purchases | `orphan_product` | 17 | `product_id` not in the catalog |
| purchases | `non_positive_quantity` | 17 | Quantity of 0 or negative |
| purchases | `before_signup` | 16 | Purchased 1–30 days before the user's signup (clock skew or a backdated receipt) |
| purchases | `points_mismatch` | 16 | `points_earned` doesn't match the points rule (a double-points bug) |
| referrals | `self_referral` | 2 | Invite sent to the referrer's own email, sometimes plus-addressed |
| referrals | `existing_member_converted` | 2 | "Converted" to someone who was already a member |
| referrals | `duplicate_send` | 2 | The same invite sent again within minutes |
| referrals | `status_mismatch` | 2 | Status `converted` with no referred user or `converted_at` |
| referrals | `converted_before_sent` | 2 | `converted_at` earlier than `sent_at` |

## Known issues in the provided code

Only the midnight signups and the CSV encoding were changed in the generator. The rest were left as provided; each one is either handled by the pipeline or avoided.

| Issue | Effect | Handling |
|---|---|---|
| `generate_users` counts signup dates back from `start_date` | Every signup falls in 2023 (a handful on Jan 1, 2024), so nobody joins during the `start_date`–`end_date` window | Kept as designed. Purchases start at each signup so cohorts are observable; referral activity ends with the last signup (see [Timeline](#timeline)) |
| `generate_users` emails are `first.last` plus a number from 1–999 | 2 duplicate emails at the default seed, although the original schema has `email UNIQUE` | Data-quality warning; joins use `user_id`, never email |
| `save_to_sqlite` runs `CREATE TABLE IF NOT EXISTS` and then inserts | Every rerun appends a second copy of every table | The pipeline reads the CSVs, which are overwritten on each run |
| `save_to_sqlite` infers column types from the first row | A `None` in the first referral would make `referred_user_id` a TEXT column | The pipeline casts every column explicitly |
| `generate_products` makes `n // 25` products per item, but there are 26 items | No Oil products; Pantry has 16 products instead of 20; 5 product names repeat | `product_id` is the key; names aren't unique |
| `generate_schools` needs a unique name/type pair and there are only 105 | Loops forever above 105 schools | Scale runs use 100 schools or fewer |
| School city, state and zip are chosen independently | Combinations such as "Springfield, TX" with a random zip | City and state are treated as the district; zip isn't used |
| `generate_users` subtracted whole days from a midnight date | Every signup, and so every referral `converted_at`, was at exactly midnight | **Fixed:** adds a time of day from the weekday hour curve (one line added) |
| `save_to_csv` opens files without an encoding | Python then uses the system default: UTF-8 on macOS and Linux, but usually cp1252 on Windows. The brand "Shimago-Domínguez" is written as an invalid UTF-8 byte, and DuckDB rejects `products.csv` | **Fixed:** `encoding='utf-8'` added to the `open()` call. Every file the pipeline reads or writes names UTF-8 too |
| `str \| None` type hint; sqlite3 default datetime adapter | Requires Python 3.10+; prints a deprecation warning on 3.12+ | Harmless |

## Simplifications

- One school and one `user_type` per user, for life.
- Churn is permanent: a user who stops buying never comes back, and churn only affects buying (a churned user can still send a referral invite).
- Static catalog: prices never change and nothing is discontinued.
- Each purchase is one product (any quantity). There are no multi-item baskets or receipts, and no returns or refunds.
- A district's income level affects every user in it equally; there is no household-level income.
- No device or payment data, so self-referrals can only be detected by email.
- No `clicked_at` (it isn't in the field contract), so funnel timing is sent-to-converted only.
- Naive timestamps in a single time zone.
- Referral bonuses and payouts aren't generated as transactions; the pipeline calculates them.
- No fraud rings or bot traffic beyond the planted issues above.

## What the default run produces

| Measure | Value |
|---|---|
| Rows | 50 schools, 21 districts, 1,000 users, 100 products, 10,000 purchases (9,883 clean), 1,000 referrals |
| Signup dates | 2023-01-01 to 2024-01-01 |
| Purchase dates | 2023-01-01 to 2024-06-30 |
| Monthly purchases | 121 in January 2023, rising to about 770 a month from September to December 2023 and a March 2024 peak of 835, then falling to 473 by June 2024 as users churn and nobody new joins |
| Users with no purchases / top 10% share of purchases | 17% / 42% |
| Weekend vs weekday volume per day | 1.4x |
| Purchases on promotion | 11% |
| Spend / donated to schools | $88.2k / $2.4k (lowest school $10, median $47, highest $85) |
| Retention after signup (2023 cohorts) | 59% active in month 1, 46% in month 3, 37% in month 6. Referred users run slightly ahead (51% vs 45% in month 3; 37% vs 36% in month 6) |
| Referral funnel | 1,000 invites → 48% clicked → 17.3% converted (171 signups) |
| Users who sent any invite | 23% (median 2 invites, top sender 49; the top 5% of senders sent 27% of invites) |
| Chain depth | 141 users at depth 1, 23 at depth 2, 5 at depth 3, 2 at depth 4 |
| Sent to signup | median 8.7 hours, p90 23 hours |
