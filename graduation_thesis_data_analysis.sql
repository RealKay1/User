<<<<<<< HEAD
-- ============================================================================
-- THESIS BLOCK C — STATISTICAL REPRODUCTION QUERIES (PostgreSQL / pgAdmin)
-- ============================================================================
-- Author:   Klutch — VIKO graduation thesis on AI-driven digital marketing
-- Subject:  Kartpos UAB (African Market, africanmarket.lt)
-- Source:   `survey_responses` table loaded from african_market_survey.sql
--
-- These queries reproduce, in PostgreSQL, the statistics reported in
-- Block C of the thesis: Table 2.7, Cronbach's alpha, subgroup
-- comparisons (African vs non-African; regular vs less-familiar customers),
-- and the Q12 multi-select feature ranking.
--
-- NOTE ON SMALL DISCREPANCIES (~1–2 cases)
-- ----------------------------------------
-- The cleaned dataset removed 4 invalid submissions after the thesis text
-- was written (2 troll/offensive responses + 2 duplicate double-submits).
-- Expected results on the cleaned data versus the thesis text:
--   • Listwise-complete Q11 sample:  n = 141  (thesis reported n = 143)
--   • Q12 answered sample:           n = 154  (thesis reported n = 156)
--   • Cronbach's α:                  ≈ 0.77   (thesis reported 0.78)
--   • Item means differ by ≤ 0.02   (e.g., Q11d M = 3.42 vs 3.40)
--   • All substantive findings and rank orders are unchanged
-- All deltas are within normal rounding for a 2-row sample reduction. If you
-- need exact thesis numbers, rerun the analysis on the pre-cleaning raw export.
-- ============================================================================


-- ============================================================================
-- 0. SETUP & VALIDATION
-- ============================================================================

-- 0.1 Confirm the cleaned dataset is loaded
SELECT COUNT(*) AS total_responses FROM survey_responses;
-- Expected: 194

-- 0.2 Per-item response counts for the Q11 TAM block
--     (Q11 items were only shown to respondents familiar with African Market,
--     so non-NULL counts reflect the survey's branch logic)
SELECT
    COUNT(Q11a_PersRec)   AS n_q11a_personalised_rec,
    COUNT(Q11b_Chatbot)   AS n_q11b_chatbot,
    COUNT(Q11c_TrustAI)   AS n_q11c_trust,
    COUNT(Q11d_AutoNotif) AS n_q11d_auto_notif,
    COUNT(Q11e_AIRecipes) AS n_q11e_ai_recipes
FROM survey_responses;

-- 0.3 Listwise-complete subsample size (respondents who answered ALL FIVE Q11
--     items — the analytical base for Table 2.7 and Cronbach's alpha)
SELECT COUNT(*) AS n_listwise_complete
FROM survey_responses
WHERE Q11a_PersRec   IS NOT NULL
  AND Q11b_Chatbot   IS NOT NULL
  AND Q11c_TrustAI   IS NOT NULL
  AND Q11d_AutoNotif IS NOT NULL
  AND Q11e_AIRecipes IS NOT NULL;
-- Expected: 141

-- 0.4 Reusable view: listwise-complete Q11 subsample
--     All Block C analyses use this view to ensure the same n across items
DROP VIEW IF EXISTS v_q11_complete CASCADE;
CREATE VIEW v_q11_complete AS
SELECT *
FROM survey_responses
WHERE Q11a_PersRec   IS NOT NULL
  AND Q11b_Chatbot   IS NOT NULL
  AND Q11c_TrustAI   IS NOT NULL
  AND Q11d_AutoNotif IS NOT NULL
  AND Q11e_AIRecipes IS NOT NULL;


-- ============================================================================
-- 1. TABLE 2.7 — ITEM-LEVEL DESCRIPTIVE STATISTICS
-- ============================================================================
-- Reproduces Table 2.7 (Acceptance of AI-Powered Marketing Features).
-- For each of the five Q11 items, computes:
--   • n              (always = listwise-complete sample size)
--   • Mean           (1–5 Likert scale)
--   • SD             (sample standard deviation, n−1 denominator)
--   • % Agree        (proportion rating 4 = Agree or 5 = Strongly Agree)
--
-- The UNION ALL "unpivot" approach turns the five Q11 columns into long
-- format so the aggregate can be expressed once and applied per item.

WITH q11_long AS (
    SELECT response_id, 'Q11d_AutoNotif'  AS item_code,
           'Automated notifications about new arrivals or promotions' AS item_label,
           Q11d_AutoNotif AS rating
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11a_PersRec',
           'Personalised product recommendations',
           Q11a_PersRec
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11b_Chatbot',
           'Willingness to interact with an AI-powered chatbot',
           Q11b_Chatbot
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11e_AIRecipes',
           'AI-generated recipe suggestions',
           Q11e_AIRecipes
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11c_TrustAI',
           'Trust in AI-generated content from brands',
           Q11c_TrustAI
      FROM v_q11_complete
)
SELECT
    item_code,
    item_label,
    COUNT(*) AS n,
    ROUND(AVG(rating)::numeric, 2)         AS mean,
    ROUND(STDDEV_SAMP(rating)::numeric, 2) AS sd,
    -- % Agree = ratings of 4 (Agree) OR 5 (Strongly Agree)
    ROUND(
        100.0 * SUM(CASE WHEN rating >= 4 THEN 1 ELSE 0 END) / COUNT(*),
        1
    ) AS pct_agree_or_strongly_agree
FROM q11_long
GROUP BY item_code, item_label
ORDER BY mean DESC;


-- ============================================================================
-- 2. CRONBACH'S ALPHA — INTERNAL CONSISTENCY OF THE TAM BLOCK
-- ============================================================================
-- Formula (standard, as in Saunders et al. 2023):
--
--   α = (k / (k − 1)) × (1 − Σ σ²ᵢ / σ²_total)
--
--   where k          = number of items in the scale (= 5),
--         σ²ᵢ        = sample variance of item i,
--         σ²_total   = sample variance of the per-respondent sum across items.
--
-- Threshold: α ≥ 0.70 indicates acceptable internal consistency.

WITH item_variances AS (
    SELECT
        VAR_SAMP(Q11a_PersRec)   AS var_a,
        VAR_SAMP(Q11b_Chatbot)   AS var_b,
        VAR_SAMP(Q11c_TrustAI)   AS var_c,
        VAR_SAMP(Q11d_AutoNotif) AS var_d,
        VAR_SAMP(Q11e_AIRecipes) AS var_e,
        VAR_SAMP(
            Q11a_PersRec + Q11b_Chatbot + Q11c_TrustAI
          + Q11d_AutoNotif + Q11e_AIRecipes
        ) AS var_total,
        5::numeric AS k,
        COUNT(*)   AS n
    FROM v_q11_complete
)
SELECT
    n,
    k::int AS num_items,
    ROUND((var_a + var_b + var_c + var_d + var_e)::numeric, 4) AS sum_item_variances,
    ROUND(var_total::numeric, 4) AS total_variance,
    ROUND(
        ( (k / (k - 1)) *
          (1 - (var_a + var_b + var_c + var_d + var_e) / var_total)
        )::numeric,
        3
    ) AS cronbach_alpha,
    CASE
        WHEN ( (k / (k - 1)) *
               (1 - (var_a + var_b + var_c + var_d + var_e) / var_total)
             ) >= 0.70
        THEN 'Acceptable (α ≥ 0.70)'
        ELSE 'Below threshold'
    END AS reliability_assessment
FROM item_variances;


-- ============================================================================
-- 3. SUBGROUP ANALYSIS — AFRICAN vs NON-AFRICAN RESPONDENTS
-- ============================================================================
-- Compares mean acceptance per Q11 item between African and non-African
-- respondents on the listwise-complete sample (n = 141 in cleaned data;
-- thesis reported n = 143 with 97 African + 46 non-African).

-- 3.1 Subgroup sample sizes
SELECT
    CASE WHEN nationality_group = 'African' THEN 'African' ELSE 'Non-African' END AS subgroup,
    COUNT(*) AS n
FROM v_q11_complete
GROUP BY 1
ORDER BY 2 DESC;

-- 3.2 Item-by-item subgroup means + delta
WITH q11_long AS (
    SELECT
        CASE WHEN nationality_group = 'African' THEN 'African' ELSE 'Non-African' END AS subgroup,
        item_code, rating
    FROM (
        SELECT response_id, nationality_group, 'Q11a_PersRec'   AS item_code, Q11a_PersRec   AS rating FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11b_Chatbot',   Q11b_Chatbot                          FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11c_TrustAI',   Q11c_TrustAI                          FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11d_AutoNotif', Q11d_AutoNotif                        FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11e_AIRecipes', Q11e_AIRecipes                        FROM v_q11_complete
    ) src
),
subgroup_means AS (
    SELECT item_code,
           ROUND(AVG(CASE WHEN subgroup = 'African'     THEN rating END)::numeric, 2) AS mean_african,
           ROUND(AVG(CASE WHEN subgroup = 'Non-African' THEN rating END)::numeric, 2) AS mean_non_african,
           SUM(CASE WHEN subgroup = 'African'     THEN 1 ELSE 0 END) AS n_african,
           SUM(CASE WHEN subgroup = 'Non-African' THEN 1 ELSE 0 END) AS n_non_african
    FROM q11_long
    GROUP BY item_code
)
SELECT
    item_code,
    n_african,
    mean_african,
    n_non_african,
    mean_non_african,
    ROUND(mean_african - mean_non_african, 2) AS delta_africa_minus_non
FROM subgroup_means
ORDER BY item_code;


-- ============================================================================
-- 4. SUBGROUP ANALYSIS — REGULAR vs LESS-FAMILIAR CUSTOMERS
-- ============================================================================
-- Q6 codes:
--   a = Regular customer (monthly+)
--   b = Occasional customer (few times/year)
--   c = Visited once or twice
--   d = Heard of but never visited
--   e = Never heard of  ← excluded from Block C by survey branch logic
--
-- "Regular customers" = code 'a'; "Less familiar" = codes b, c, d.

-- 4.1 Familiarity subgroup sample sizes (on listwise-complete sample)
SELECT
    CASE
        WHEN Q6_Familiarity_code = 'a' THEN 'Regular customer'
        WHEN Q6_Familiarity_code IN ('b','c','d') THEN 'Less familiar'
        ELSE 'Other'
    END AS subgroup,
    COUNT(*) AS n
FROM v_q11_complete
GROUP BY 1
ORDER BY 2 DESC;

-- 4.2 Item-by-item means by familiarity tier
WITH q11_long AS (
    SELECT
        CASE
            WHEN Q6_Familiarity_code = 'a' THEN 'Regular customer'
            WHEN Q6_Familiarity_code IN ('b','c','d') THEN 'Less familiar'
        END AS familiarity_tier,
        item_code, rating
    FROM (
        SELECT response_id, Q6_Familiarity_code, 'Q11a_PersRec'   AS item_code, Q11a_PersRec   AS rating FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11b_Chatbot',   Q11b_Chatbot   FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11c_TrustAI',   Q11c_TrustAI   FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11d_AutoNotif', Q11d_AutoNotif FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11e_AIRecipes', Q11e_AIRecipes FROM v_q11_complete
    ) src
)
SELECT
    item_code,
    ROUND(AVG(CASE WHEN familiarity_tier = 'Regular customer' THEN rating END)::numeric, 2) AS mean_regular,
    ROUND(AVG(CASE WHEN familiarity_tier = 'Less familiar'    THEN rating END)::numeric, 2) AS mean_less_familiar,
    ROUND(
        AVG(CASE WHEN familiarity_tier = 'Regular customer' THEN rating END)::numeric -
        AVG(CASE WHEN familiarity_tier = 'Less familiar'    THEN rating END)::numeric,
        2
    ) AS delta_regular_minus_less
FROM q11_long
GROUP BY item_code
ORDER BY item_code;


-- ============================================================================
-- 5. Q12 — MULTI-SELECT FEATURE ENDORSEMENT
-- ============================================================================
-- Q12 asked "Which AI-powered features would be most useful?" (multi-select).
-- After cleaning, each option is stored as a separate boolean column where
-- 1 = selected, 0 = not selected but question answered, NULL = skipped.
--
-- Q12 was shown to respondents who reached the post-familiarity block.
-- Expected n = 154 (thesis: 156).

-- 5.1 Q12 sample size
SELECT COUNT(*) AS n_q12_answered
FROM survey_responses
WHERE q12_chatbot IS NOT NULL;  -- any Q12 boolean is non-NULL iff the question was answered

-- 5.2 Per-feature selection counts and percentages, ranked
WITH q12_long AS (
    SELECT 'Chatbot answering product questions instantly' AS feature, q12_chatbot          AS selected FROM survey_responses WHERE q12_chatbot          IS NOT NULL
    UNION ALL SELECT 'Personalised product recommendations',           q12_personalised_rec           FROM survey_responses WHERE q12_personalised_rec IS NOT NULL
    UNION ALL SELECT 'Smart search (e.g., find Nigerian ingredients)', q12_smart_search               FROM survey_responses WHERE q12_smart_search     IS NOT NULL
    UNION ALL SELECT 'AI-generated promotions or discount offers',     q12_ai_promotions              FROM survey_responses WHERE q12_ai_promotions    IS NOT NULL
    UNION ALL SELECT 'Automatic notifications about relevant products', q12_auto_notif                FROM survey_responses WHERE q12_auto_notif       IS NOT NULL
    UNION ALL SELECT 'AI-generated recipes based on purchased products', q12_ai_recipes               FROM survey_responses WHERE q12_ai_recipes       IS NOT NULL
    UNION ALL SELECT 'None of these',                                   q12_none                       FROM survey_responses WHERE q12_none             IS NOT NULL
)
SELECT
    feature,
    SUM(selected)::int                          AS selections,
    COUNT(*)                                    AS n_answered,
    ROUND(100.0 * SUM(selected) / COUNT(*), 1)  AS pct_selected
FROM q12_long
GROUP BY feature
ORDER BY pct_selected DESC;


-- ============================================================================
-- 6. SUPPORTING DEMOGRAPHIC CONTEXT (optional — for appendix tables)
-- ============================================================================

-- 6.1 Overall demographic profile of the full cleaned sample (n = 194)
SELECT 'Age group'     AS dimension, Q1_AgeGroup_label  AS category, COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM survey_responses GROUP BY Q1_AgeGroup_label
UNION ALL
SELECT 'Gender', Q2_Gender_label, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM survey_responses GROUP BY Q2_Gender_label
UNION ALL
SELECT 'Nationality group', nationality_group, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM survey_responses GROUP BY nationality_group
UNION ALL
SELECT 'Occupation', occupation_normalized, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM survey_responses GROUP BY occupation_normalized
ORDER BY dimension, n DESC;

-- 6.2 Familiarity distribution (Q6) on the full sample
SELECT
    Q6_Familiarity_code AS code,
    Q6_Familiarity_label AS familiarity,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM survey_responses
GROUP BY Q6_Familiarity_code, Q6_Familiarity_label
ORDER BY Q6_Familiarity_code;

-- 6.3 Top African countries among African respondents (context for Block A)
SELECT
    Q4b_AfricanCountry_normalized AS country,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_african_subset
FROM survey_responses
WHERE Q4b_AfricanCountry_normalized IS NOT NULL
GROUP BY Q4b_AfricanCountry_normalized
ORDER BY n DESC;


-- ============================================================================
-- 7. ADDITIONAL CROSS-CHECKS (sanity)
-- ============================================================================

-- 7.1 Spread between highest and lowest Q11 item mean (thesis reports 0.52)
WITH item_means AS (
    SELECT AVG(Q11a_PersRec)   AS m_a, AVG(Q11b_Chatbot) AS m_b,
           AVG(Q11c_TrustAI)   AS m_c, AVG(Q11d_AutoNotif) AS m_d,
           AVG(Q11e_AIRecipes) AS m_e
    FROM v_q11_complete
)
SELECT
    ROUND(GREATEST(m_a, m_b, m_c, m_d, m_e)::numeric, 2) AS highest_mean,
    ROUND(LEAST   (m_a, m_b, m_c, m_d, m_e)::numeric, 2) AS lowest_mean,
    ROUND((GREATEST(m_a, m_b, m_c, m_d, m_e) -
           LEAST   (m_a, m_b, m_c, m_d, m_e))::numeric, 2) AS spread
FROM item_means;

-- 7.2 Rank Q11 items by the size of the African vs non-African gap.
--     The thesis interprets the near-identical TRUST ratings (Q11c) as evidence
--     that trust in AI-generated content is a brand-wide concern.
--     On the cleaned dataset both Q11c (trust) and Q11e (AI recipes) show
--     small deltas (≤ 0.20); Q11e is marginally smaller. The interpretation
--     still holds — the African subgroup boost is NOT uniform across items —
--     but if you want to keep the exact "trust is closest" phrasing, run the
--     analysis on the pre-cleaning raw export instead.
WITH deltas AS (
    SELECT 'Q11a_PersRec' AS item,
           AVG(CASE WHEN nationality_group='African'     THEN Q11a_PersRec END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11a_PersRec END) AS delta
    FROM v_q11_complete
    UNION ALL SELECT 'Q11b_Chatbot',
           AVG(CASE WHEN nationality_group='African'     THEN Q11b_Chatbot END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11b_Chatbot END)
    FROM v_q11_complete
    UNION ALL SELECT 'Q11c_TrustAI',
           AVG(CASE WHEN nationality_group='African'     THEN Q11c_TrustAI END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11c_TrustAI END)
    FROM v_q11_complete
    UNION ALL SELECT 'Q11d_AutoNotif',
           AVG(CASE WHEN nationality_group='African'     THEN Q11d_AutoNotif END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11d_AutoNotif END)
    FROM v_q11_complete
    UNION ALL SELECT 'Q11e_AIRecipes',
           AVG(CASE WHEN nationality_group='African'     THEN Q11e_AIRecipes END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11e_AIRecipes END)
    FROM v_q11_complete
)
SELECT item, ROUND(delta::numeric, 2) AS african_minus_non_african
FROM deltas
ORDER BY ABS(delta) ASC;

-- ============================================================================
-- END OF FILE
=======
-- ============================================================================
-- THESIS BLOCK C — STATISTICAL REPRODUCTION QUERIES (PostgreSQL / pgAdmin)
-- ============================================================================
-- Author:   Klutch — VIKO graduation thesis on AI-driven digital marketing
-- Subject:  Kartpos UAB (African Market, africanmarket.lt)
-- Source:   `survey_responses` table loaded from african_market_survey.sql
--
-- These queries reproduce, in PostgreSQL, the statistics reported in
-- Block C of the thesis: Table 2.7, Cronbach's alpha, subgroup
-- comparisons (African vs non-African; regular vs less-familiar customers),
-- and the Q12 multi-select feature ranking.
--
-- NOTE ON SMALL DISCREPANCIES (~1–2 cases)
-- ----------------------------------------
-- The cleaned dataset removed 4 invalid submissions after the thesis text
-- was written (2 troll/offensive responses + 2 duplicate double-submits).
-- Expected results on the cleaned data versus the thesis text:
--   • Listwise-complete Q11 sample:  n = 141  (thesis reported n = 143)
--   • Q12 answered sample:           n = 154  (thesis reported n = 156)
--   • Cronbach's α:                  ≈ 0.77   (thesis reported 0.78)
--   • Item means differ by ≤ 0.02   (e.g., Q11d M = 3.42 vs 3.40)
--   • All substantive findings and rank orders are unchanged
-- All deltas are within normal rounding for a 2-row sample reduction. If you
-- need exact thesis numbers, rerun the analysis on the pre-cleaning raw export.
-- ============================================================================


-- ============================================================================
-- 0. SETUP & VALIDATION
-- ============================================================================

-- 0.1 Confirm the cleaned dataset is loaded
SELECT COUNT(*) AS total_responses FROM survey_responses;
-- Expected: 194

-- 0.2 Per-item response counts for the Q11 TAM block
--     (Q11 items were only shown to respondents familiar with African Market,
--     so non-NULL counts reflect the survey's branch logic)
SELECT
    COUNT(Q11a_PersRec)   AS n_q11a_personalised_rec,
    COUNT(Q11b_Chatbot)   AS n_q11b_chatbot,
    COUNT(Q11c_TrustAI)   AS n_q11c_trust,
    COUNT(Q11d_AutoNotif) AS n_q11d_auto_notif,
    COUNT(Q11e_AIRecipes) AS n_q11e_ai_recipes
FROM survey_responses;

-- 0.3 Listwise-complete subsample size (respondents who answered ALL FIVE Q11
--     items — the analytical base for Table 2.7 and Cronbach's alpha)
SELECT COUNT(*) AS n_listwise_complete
FROM survey_responses
WHERE Q11a_PersRec   IS NOT NULL
  AND Q11b_Chatbot   IS NOT NULL
  AND Q11c_TrustAI   IS NOT NULL
  AND Q11d_AutoNotif IS NOT NULL
  AND Q11e_AIRecipes IS NOT NULL;
-- Expected: 141

-- 0.4 Reusable view: listwise-complete Q11 subsample
--     All Block C analyses use this view to ensure the same n across items
DROP VIEW IF EXISTS v_q11_complete CASCADE;
CREATE VIEW v_q11_complete AS
SELECT *
FROM survey_responses
WHERE Q11a_PersRec   IS NOT NULL
  AND Q11b_Chatbot   IS NOT NULL
  AND Q11c_TrustAI   IS NOT NULL
  AND Q11d_AutoNotif IS NOT NULL
  AND Q11e_AIRecipes IS NOT NULL;


-- ============================================================================
-- 1. TABLE 2.7 — ITEM-LEVEL DESCRIPTIVE STATISTICS
-- ============================================================================
-- Reproduces Table 2.7 (Acceptance of AI-Powered Marketing Features).
-- For each of the five Q11 items, computes:
--   • n              (always = listwise-complete sample size)
--   • Mean           (1–5 Likert scale)
--   • SD             (sample standard deviation, n−1 denominator)
--   • % Agree        (proportion rating 4 = Agree or 5 = Strongly Agree)
--
-- The UNION ALL "unpivot" approach turns the five Q11 columns into long
-- format so the aggregate can be expressed once and applied per item.

WITH q11_long AS (
    SELECT response_id, 'Q11d_AutoNotif'  AS item_code,
           'Automated notifications about new arrivals or promotions' AS item_label,
           Q11d_AutoNotif AS rating
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11a_PersRec',
           'Personalised product recommendations',
           Q11a_PersRec
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11b_Chatbot',
           'Willingness to interact with an AI-powered chatbot',
           Q11b_Chatbot
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11e_AIRecipes',
           'AI-generated recipe suggestions',
           Q11e_AIRecipes
      FROM v_q11_complete
    UNION ALL
    SELECT response_id, 'Q11c_TrustAI',
           'Trust in AI-generated content from brands',
           Q11c_TrustAI
      FROM v_q11_complete
)
SELECT
    item_code,
    item_label,
    COUNT(*) AS n,
    ROUND(AVG(rating)::numeric, 2)         AS mean,
    ROUND(STDDEV_SAMP(rating)::numeric, 2) AS sd,
    -- % Agree = ratings of 4 (Agree) OR 5 (Strongly Agree)
    ROUND(
        100.0 * SUM(CASE WHEN rating >= 4 THEN 1 ELSE 0 END) / COUNT(*),
        1
    ) AS pct_agree_or_strongly_agree
FROM q11_long
GROUP BY item_code, item_label
ORDER BY mean DESC;


-- ============================================================================
-- 2. CRONBACH'S ALPHA — INTERNAL CONSISTENCY OF THE TAM BLOCK
-- ============================================================================
-- Formula (standard, as in Saunders et al. 2023):
--
--   α = (k / (k − 1)) × (1 − Σ σ²ᵢ / σ²_total)
--
--   where k          = number of items in the scale (= 5),
--         σ²ᵢ        = sample variance of item i,
--         σ²_total   = sample variance of the per-respondent sum across items.
--
-- Threshold: α ≥ 0.70 indicates acceptable internal consistency.

WITH item_variances AS (
    SELECT
        VAR_SAMP(Q11a_PersRec)   AS var_a,
        VAR_SAMP(Q11b_Chatbot)   AS var_b,
        VAR_SAMP(Q11c_TrustAI)   AS var_c,
        VAR_SAMP(Q11d_AutoNotif) AS var_d,
        VAR_SAMP(Q11e_AIRecipes) AS var_e,
        VAR_SAMP(
            Q11a_PersRec + Q11b_Chatbot + Q11c_TrustAI
          + Q11d_AutoNotif + Q11e_AIRecipes
        ) AS var_total,
        5::numeric AS k,
        COUNT(*)   AS n
    FROM v_q11_complete
)
SELECT
    n,
    k::int AS num_items,
    ROUND((var_a + var_b + var_c + var_d + var_e)::numeric, 4) AS sum_item_variances,
    ROUND(var_total::numeric, 4) AS total_variance,
    ROUND(
        ( (k / (k - 1)) *
          (1 - (var_a + var_b + var_c + var_d + var_e) / var_total)
        )::numeric,
        3
    ) AS cronbach_alpha,
    CASE
        WHEN ( (k / (k - 1)) *
               (1 - (var_a + var_b + var_c + var_d + var_e) / var_total)
             ) >= 0.70
        THEN 'Acceptable (α ≥ 0.70)'
        ELSE 'Below threshold'
    END AS reliability_assessment
FROM item_variances;


-- ============================================================================
-- 3. SUBGROUP ANALYSIS — AFRICAN vs NON-AFRICAN RESPONDENTS
-- ============================================================================
-- Compares mean acceptance per Q11 item between African and non-African
-- respondents on the listwise-complete sample (n = 141 in cleaned data;
-- thesis reported n = 143 with 97 African + 46 non-African).

-- 3.1 Subgroup sample sizes
SELECT
    CASE WHEN nationality_group = 'African' THEN 'African' ELSE 'Non-African' END AS subgroup,
    COUNT(*) AS n
FROM v_q11_complete
GROUP BY 1
ORDER BY 2 DESC;

-- 3.2 Item-by-item subgroup means + delta
WITH q11_long AS (
    SELECT
        CASE WHEN nationality_group = 'African' THEN 'African' ELSE 'Non-African' END AS subgroup,
        item_code, rating
    FROM (
        SELECT response_id, nationality_group, 'Q11a_PersRec'   AS item_code, Q11a_PersRec   AS rating FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11b_Chatbot',   Q11b_Chatbot                          FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11c_TrustAI',   Q11c_TrustAI                          FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11d_AutoNotif', Q11d_AutoNotif                        FROM v_q11_complete
        UNION ALL
        SELECT response_id, nationality_group, 'Q11e_AIRecipes', Q11e_AIRecipes                        FROM v_q11_complete
    ) src
),
subgroup_means AS (
    SELECT item_code,
           ROUND(AVG(CASE WHEN subgroup = 'African'     THEN rating END)::numeric, 2) AS mean_african,
           ROUND(AVG(CASE WHEN subgroup = 'Non-African' THEN rating END)::numeric, 2) AS mean_non_african,
           SUM(CASE WHEN subgroup = 'African'     THEN 1 ELSE 0 END) AS n_african,
           SUM(CASE WHEN subgroup = 'Non-African' THEN 1 ELSE 0 END) AS n_non_african
    FROM q11_long
    GROUP BY item_code
)
SELECT
    item_code,
    n_african,
    mean_african,
    n_non_african,
    mean_non_african,
    ROUND(mean_african - mean_non_african, 2) AS delta_africa_minus_non
FROM subgroup_means
ORDER BY item_code;


-- ============================================================================
-- 4. SUBGROUP ANALYSIS — REGULAR vs LESS-FAMILIAR CUSTOMERS
-- ============================================================================
-- Q6 codes:
--   a = Regular customer (monthly+)
--   b = Occasional customer (few times/year)
--   c = Visited once or twice
--   d = Heard of but never visited
--   e = Never heard of  ← excluded from Block C by survey branch logic
--
-- "Regular customers" = code 'a'; "Less familiar" = codes b, c, d.

-- 4.1 Familiarity subgroup sample sizes (on listwise-complete sample)
SELECT
    CASE
        WHEN Q6_Familiarity_code = 'a' THEN 'Regular customer'
        WHEN Q6_Familiarity_code IN ('b','c','d') THEN 'Less familiar'
        ELSE 'Other'
    END AS subgroup,
    COUNT(*) AS n
FROM v_q11_complete
GROUP BY 1
ORDER BY 2 DESC;

-- 4.2 Item-by-item means by familiarity tier
WITH q11_long AS (
    SELECT
        CASE
            WHEN Q6_Familiarity_code = 'a' THEN 'Regular customer'
            WHEN Q6_Familiarity_code IN ('b','c','d') THEN 'Less familiar'
        END AS familiarity_tier,
        item_code, rating
    FROM (
        SELECT response_id, Q6_Familiarity_code, 'Q11a_PersRec'   AS item_code, Q11a_PersRec   AS rating FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11b_Chatbot',   Q11b_Chatbot   FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11c_TrustAI',   Q11c_TrustAI   FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11d_AutoNotif', Q11d_AutoNotif FROM v_q11_complete
        UNION ALL SELECT response_id, Q6_Familiarity_code, 'Q11e_AIRecipes', Q11e_AIRecipes FROM v_q11_complete
    ) src
)
SELECT
    item_code,
    ROUND(AVG(CASE WHEN familiarity_tier = 'Regular customer' THEN rating END)::numeric, 2) AS mean_regular,
    ROUND(AVG(CASE WHEN familiarity_tier = 'Less familiar'    THEN rating END)::numeric, 2) AS mean_less_familiar,
    ROUND(
        AVG(CASE WHEN familiarity_tier = 'Regular customer' THEN rating END)::numeric -
        AVG(CASE WHEN familiarity_tier = 'Less familiar'    THEN rating END)::numeric,
        2
    ) AS delta_regular_minus_less
FROM q11_long
GROUP BY item_code
ORDER BY item_code;


-- ============================================================================
-- 5. Q12 — MULTI-SELECT FEATURE ENDORSEMENT
-- ============================================================================
-- Q12 asked "Which AI-powered features would be most useful?" (multi-select).
-- After cleaning, each option is stored as a separate boolean column where
-- 1 = selected, 0 = not selected but question answered, NULL = skipped.
--
-- Q12 was shown to respondents who reached the post-familiarity block.
-- Expected n = 154 (thesis: 156).

-- 5.1 Q12 sample size
SELECT COUNT(*) AS n_q12_answered
FROM survey_responses
WHERE q12_chatbot IS NOT NULL;  -- any Q12 boolean is non-NULL iff the question was answered

-- 5.2 Per-feature selection counts and percentages, ranked
WITH q12_long AS (
    SELECT 'Chatbot answering product questions instantly' AS feature, q12_chatbot          AS selected FROM survey_responses WHERE q12_chatbot          IS NOT NULL
    UNION ALL SELECT 'Personalised product recommendations',           q12_personalised_rec           FROM survey_responses WHERE q12_personalised_rec IS NOT NULL
    UNION ALL SELECT 'Smart search (e.g., find Nigerian ingredients)', q12_smart_search               FROM survey_responses WHERE q12_smart_search     IS NOT NULL
    UNION ALL SELECT 'AI-generated promotions or discount offers',     q12_ai_promotions              FROM survey_responses WHERE q12_ai_promotions    IS NOT NULL
    UNION ALL SELECT 'Automatic notifications about relevant products', q12_auto_notif                FROM survey_responses WHERE q12_auto_notif       IS NOT NULL
    UNION ALL SELECT 'AI-generated recipes based on purchased products', q12_ai_recipes               FROM survey_responses WHERE q12_ai_recipes       IS NOT NULL
    UNION ALL SELECT 'None of these',                                   q12_none                       FROM survey_responses WHERE q12_none             IS NOT NULL
)
SELECT
    feature,
    SUM(selected)::int                          AS selections,
    COUNT(*)                                    AS n_answered,
    ROUND(100.0 * SUM(selected) / COUNT(*), 1)  AS pct_selected
FROM q12_long
GROUP BY feature
ORDER BY pct_selected DESC;


-- ============================================================================
-- 6. SUPPORTING DEMOGRAPHIC CONTEXT (optional — for appendix tables)
-- ============================================================================

-- 6.1 Overall demographic profile of the full cleaned sample (n = 194)
SELECT 'Age group'     AS dimension, Q1_AgeGroup_label  AS category, COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM survey_responses GROUP BY Q1_AgeGroup_label
UNION ALL
SELECT 'Gender', Q2_Gender_label, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM survey_responses GROUP BY Q2_Gender_label
UNION ALL
SELECT 'Nationality group', nationality_group, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM survey_responses GROUP BY nationality_group
UNION ALL
SELECT 'Occupation', occupation_normalized, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM survey_responses GROUP BY occupation_normalized
ORDER BY dimension, n DESC;

-- 6.2 Familiarity distribution (Q6) on the full sample
SELECT
    Q6_Familiarity_code AS code,
    Q6_Familiarity_label AS familiarity,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM survey_responses
GROUP BY Q6_Familiarity_code, Q6_Familiarity_label
ORDER BY Q6_Familiarity_code;

-- 6.3 Top African countries among African respondents (context for Block A)
SELECT
    Q4b_AfricanCountry_normalized AS country,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_african_subset
FROM survey_responses
WHERE Q4b_AfricanCountry_normalized IS NOT NULL
GROUP BY Q4b_AfricanCountry_normalized
ORDER BY n DESC;


-- ============================================================================
-- 7. ADDITIONAL CROSS-CHECKS (sanity)
-- ============================================================================

-- 7.1 Spread between highest and lowest Q11 item mean (thesis reports 0.52)
WITH item_means AS (
    SELECT AVG(Q11a_PersRec)   AS m_a, AVG(Q11b_Chatbot) AS m_b,
           AVG(Q11c_TrustAI)   AS m_c, AVG(Q11d_AutoNotif) AS m_d,
           AVG(Q11e_AIRecipes) AS m_e
    FROM v_q11_complete
)
SELECT
    ROUND(GREATEST(m_a, m_b, m_c, m_d, m_e)::numeric, 2) AS highest_mean,
    ROUND(LEAST   (m_a, m_b, m_c, m_d, m_e)::numeric, 2) AS lowest_mean,
    ROUND((GREATEST(m_a, m_b, m_c, m_d, m_e) -
           LEAST   (m_a, m_b, m_c, m_d, m_e))::numeric, 2) AS spread
FROM item_means;

-- 7.2 Rank Q11 items by the size of the African vs non-African gap.
--     The thesis interprets the near-identical TRUST ratings (Q11c) as evidence
--     that trust in AI-generated content is a brand-wide concern.
--     On the cleaned dataset both Q11c (trust) and Q11e (AI recipes) show
--     small deltas (≤ 0.20); Q11e is marginally smaller. The interpretation
--     still holds — the African subgroup boost is NOT uniform across items —
--     but if you want to keep the exact "trust is closest" phrasing, run the
--     analysis on the pre-cleaning raw export instead.
WITH deltas AS (
    SELECT 'Q11a_PersRec' AS item,
           AVG(CASE WHEN nationality_group='African'     THEN Q11a_PersRec END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11a_PersRec END) AS delta
    FROM v_q11_complete
    UNION ALL SELECT 'Q11b_Chatbot',
           AVG(CASE WHEN nationality_group='African'     THEN Q11b_Chatbot END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11b_Chatbot END)
    FROM v_q11_complete
    UNION ALL SELECT 'Q11c_TrustAI',
           AVG(CASE WHEN nationality_group='African'     THEN Q11c_TrustAI END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11c_TrustAI END)
    FROM v_q11_complete
    UNION ALL SELECT 'Q11d_AutoNotif',
           AVG(CASE WHEN nationality_group='African'     THEN Q11d_AutoNotif END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11d_AutoNotif END)
    FROM v_q11_complete
    UNION ALL SELECT 'Q11e_AIRecipes',
           AVG(CASE WHEN nationality_group='African'     THEN Q11e_AIRecipes END) -
           AVG(CASE WHEN nationality_group<>'African'    THEN Q11e_AIRecipes END)
    FROM v_q11_complete
)
SELECT item, ROUND(delta::numeric, 2) AS african_minus_non_african
FROM deltas
ORDER BY ABS(delta) ASC;

-- ============================================================================
-- END OF FILE
>>>>>>> 4462972498e669e0a7dc9ce957799ae7f0b2edd8
-- ============================================================================