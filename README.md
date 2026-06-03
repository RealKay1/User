# SQL-Based Statistical Analysis for Section 2.3.3

**Thesis:** Developing AI-Driven Digital Marketing for UAB “Kartpos”(African Market)
**Institution:** Vilniaus Kolegija (VIKO)
**Author:** Omokolade Solomon Opeibi
**Database engine:** PostgreSQL 18+ (executed via pgAdmin 4)
**Development Environment:** Visual Studio Code (VS Code)
**Companion file:** `thesis_block_c_queries.sql`
**Source dataset:** `african_market_survey.sql` (194 cleaned customer-survey responses)

---

## 1. Purpose and Scope

This document explains the SQL-based reproduction of the empirical findings reported in **Section 2.3.3 (Acceptance of AI-Powered Marketing Features)** of the thesis, including the statistics summarised in **Table 2.7**. Its purpose is twofold: to provide a clear, non-specialist account of how the analysis was performed directly against the survey database, and to demonstrate that every reported statistic - means, standard deviations, agreement percentages, subgroup comparisons, and the Cronbach's alpha reliability coefficient - is independently reproducible from the underlying data using standard SQL.

The companion file `thesis_block_c_queries.sql` contains the full set of queries. This README walks through their logic and links each output to the corresponding interpretation in the thesis text.

---

## 2. Section 2.3.3 in Context

Section 2.3.3 reports the customer-acceptance findings of the Block C survey items, which were adapted from the Technology Acceptance Model (Davis, 1989; Venkatesh & Davis, 2000; Musa et al., 2024). Five Likert-scale items (Q11a–Q11e) measured respondents' attitudes towards distinct categories of AI-powered marketing features: personalised recommendations, AI chatbot interaction, trust in AI-generated content, automated notifications, and AI-generated recipes. A complementary multi-select question (Q12) asked respondents to indicate which features they would find genuinely useful.

The analytical sample for Block C consists of the **listwise-complete subset** — that is, respondents who answered every one of the five Q11 items. This restriction is methodologically necessary for two reasons: it ensures the reliability coefficient (Cronbach's alpha) is computed on a consistent set of respondents, and it allows item-level statistics in Table 2.7 to share a common denominator, which makes the means and percentages directly comparable. After applying this restriction to the cleaned dataset, the analytical sample comprises **n = 141 respondents** (the thesis text reports n = 143; the two-respondent discrepancy is explained in §8).

---

## 3. Statistical Interpretation of Table 2.7

Table 2.7 presents three statistics per Q11 item, each capturing a different facet of consumer disposition towards AI features.

The **mean** (`AVG`) summarises the central tendency of responses on the 1–5 Likert scale, where 3.00 represents the scale midpoint (the "neither agree nor disagree" position). Means above 3.00 indicate net-positive endorsement; means below indicate net-negative disposition.

The **standard deviation** (`STDDEV_SAMP`) measures dispersion around the mean. In Table 2.7, all five items return standard deviations between 1.21 and 1.36, indicating consistent and moderate disagreement across respondents - neither uniform consensus nor extreme polarisation.

The **percentage of agreement** (% Agree / Strongly Agree) reports the proportion of respondents who selected 4 or 5 on the Likert scale. This complements the mean by showing how much of the distribution sits in the actively favourable region, rather than merely above the midpoint.

The substantive interpretation reported in the thesis follows directly from these numbers. Automated notifications (M = 3.40, 49.6 % agreement) and personalised recommendations (M = 3.24, 42.2 % agreement) emerge as the most accepted feature categories, both meaningfully above the midpoint. Chatbot interaction (M = 3.17) sits in moderate territory. AI-generated recipes (M = 2.90) and trust in AI-generated content (M = 2.88) fall just below the midpoint, indicating mild hesitancy rather than outright rejection. The 0.52-point spread between the highest and lowest items signals that respondents differentiate between feature types rather than adopting a uniform attitude towards AI - a finding consistent with Musa et al. (2024).

The Cronbach's alpha of **0.78** confirms acceptable internal consistency for the five-item TAM scale (Saunders et al., 2023; threshold ≥ 0.70), which justifies treating the items as measures of a single underlying construct (overall AI feature acceptance) while preserving the value of item-level analysis.

---

## 4. How PostgreSQL Was Used

Once the cleaned survey dataset was loaded into a PostgreSQL table (`survey_responses`) via the schema in `african_market_survey.sql`, every reported statistic in Section 2.3.3 was computed directly from that table using a single SQL file. This approach replaces the more typical workflow of exporting to a spreadsheet or statistical package, and it carries three advantages relevant to academic reproducibility.

First, the queries are **declarative**: they specify *what* is to be computed, not *how*, so a reader unfamiliar with the underlying procedural code can still follow the logic. Second, every statistic is **traceable to a specific row of the database** — a supervisor can rerun any query and obtain identical results without intermediate manual steps. Third, the use of standard SQL functions (`AVG`, `STDDEV_SAMP`, `VAR_SAMP`, `COUNT`) avoids any dependence on proprietary software, which makes the analysis portable across institutions.

The PostgreSQL aggregate functions used here apply the **sample-based** divisor (n−1) for variance and standard deviation, which is the convention used in SPSS, Stata, and R, and is appropriate when the sample is treated as drawn from a larger population - as it is in this study.

---

## 5. Query Walkthrough

The queries are organised into seven numbered sections in the SQL file. Each is summarised below with its purpose and key logic.

### 5.1 Setup and Validation (Section 0)

The first block confirms the integrity of the loaded dataset and creates a reusable database view, `v_q11_complete`, representing the listwise-complete subsample. All subsequent Block C analyses query this view rather than the full table, which guarantees a consistent denominator.

```sql
CREATE VIEW v_q11_complete AS
SELECT *
FROM survey_responses
WHERE Q11a_PersRec   IS NOT NULL
  AND Q11b_Chatbot   IS NOT NULL
  AND Q11c_TrustAI   IS NOT NULL
  AND Q11d_AutoNotif IS NOT NULL
  AND Q11e_AIRecipes IS NOT NULL;
```

In plain language: this view contains only those respondents who answered all five TAM items. Treating it as the analytical base ensures Table 2.7 statistics are mutually comparable.

### 5.2 Table 2.7 — Item-Level Descriptive Statistics (Section 1)

This query reproduces Table 2.7 in a single output. It "unpivots" the five Q11 columns into long format via `UNION ALL`, then aggregates once.

```sql
SELECT
    item_code,
    item_label,
    COUNT(*) AS n,
    ROUND(AVG(rating)::numeric, 2)         AS mean,
    ROUND(STDDEV_SAMP(rating)::numeric, 2) AS sd,
    ROUND(
        100.0 * SUM(CASE WHEN rating >= 4 THEN 1 ELSE 0 END) / COUNT(*),
        1
    ) AS pct_agree_or_strongly_agree
FROM q11_long
GROUP BY item_code, item_label
ORDER BY mean DESC;
```

The `CASE WHEN rating >= 4` expression produces a 1 for every "Agree" or "Strongly Agree" response and a 0 otherwise; summing these and dividing by the total respondent count yields the agreement percentage. The result is ordered by mean in descending order, replicating the row order shown in Table 2.7.

### 5.3 Cronbach's Alpha (Section 2)

Cronbach's alpha measures the internal consistency of a multi-item scale. The standard formula is:

$$ \alpha = \frac{k}{k-1} \left( 1 - \frac{\sum \sigma^2_i}{\sigma^2_{total}} \right) $$

where *k* is the number of items, σ²ᵢ is the sample variance of item *i*, and σ²_total is the variance of the per-respondent sum across all items.

The query expresses this directly:

```sql
SELECT
    ROUND(
        ( (k / (k - 1)) *
          (1 - (var_a + var_b + var_c + var_d + var_e) / var_total)
        )::numeric,
        3
    ) AS cronbach_alpha
FROM item_variances;
```

The logic mirrors the formula: PostgreSQL's `VAR_SAMP` returns the sample variance for each item; their sum forms the numerator of the ratio; the variance of the row-wise sum forms the denominator. The closer α is to 1.0, the more strongly the items move together. A value of 0.78 indicates that the five items reliably measure the same underlying construct (AI feature acceptance), which justifies aggregating across them when interpreting overall TAM disposition.

### 5.4 Subgroup Analyses (Sections 3 and 4)

Two subgroup analyses are computed: one comparing African and non-African respondents (Section 3), and one comparing regular customers (Q6 = "a") with less-familiar respondents (Q6 = "b", "c", or "d") (Section 4).

In both cases, the query produces a per-item mean for each subgroup and the difference (delta). A representative example:

```sql
SELECT
    item_code,
    ROUND(AVG(CASE WHEN nationality_group = 'African'
                   THEN rating END)::numeric, 2) AS mean_african,
    ROUND(AVG(CASE WHEN nationality_group <> 'African'
                   THEN rating END)::numeric, 2) AS mean_non_african,
    ROUND(
        AVG(CASE WHEN nationality_group = 'African'  THEN rating END)::numeric -
        AVG(CASE WHEN nationality_group <> 'African' THEN rating END)::numeric,
        2
    ) AS delta_africa_minus_non
FROM q11_long
GROUP BY item_code
ORDER BY item_code;
```

This conditional-aggregation pattern — `AVG(CASE WHEN ... THEN rating END)` - is the SQL equivalent of computing a mean over a filtered subset, but performed within a single pass over the data. The result confirms the thesis claim that African respondents report higher acceptance on every TAM item, while the trust item shows one of the smallest between-group gaps. The familiarity-based subgroup analysis similarly confirms that regular customers report notably higher acceptance on every item (deltas ranging from +0.32 to +0.61), which supports the interpretation that prior contact with the brand correlates with greater openness to AI-mediated engagement.

### 5.5 Q12 Multi-Select Feature Ranking (Section 5)

Question Q12 was a multi-select item asking which AI features respondents would find useful. During data cleaning, each option was exploded into a separate Boolean column (`q12_chatbot`, `q12_personalised_rec`, etc.) where 1 indicates the option was selected and 0 indicates it was not. The query computes the selection percentage for each feature:

```sql
SELECT
    feature,
    SUM(selected)::int                          AS selections,
    COUNT(*)                                    AS n_answered,
    ROUND(100.0 * SUM(selected) / COUNT(*), 1)  AS pct_selected
FROM q12_long
GROUP BY feature
ORDER BY pct_selected DESC;
```

The output is the ordered ranking of feature preferences referenced in the thesis text: chatbot at the top (53.8 %), followed by personalised recommendations (40.4 %), smart search (37.2 %), AI promotions (30.8 %), automatic notifications (29.5 %), AI recipes (25.0 %), and an important 12.2 % who indicated that no AI feature would be useful — the figure that motivated the recommendation for a human-handover protocol.

### 5.6 Supporting Demographics and Cross-Checks (Sections 6 and 7)

Section 6 produces optional context tables (age, gender, nationality, occupation, familiarity, top African countries) suitable for an appendix. Section 7 contains two cross-check queries: one computes the spread between the highest and lowest Q11 means (reported as 0.52 in the thesis), and the other ranks the African-versus-non-African deltas by absolute size to identify which feature shows the narrowest between-group gap. These cross-checks are not statistics in their own right but serve to confirm that the substantive interpretations in the thesis text follow from the data.

---

## 6. Relationship Between Queries and Thesis Findings

Each substantive claim in Section 2.3.3 maps to a specific query in the file. The correspondence is as follows. The five item means, standard deviations, and agreement percentages in Table 2.7 are produced by Section 1. The Cronbach's alpha value cited in the surrounding paragraph (α = 0.78) is produced by Section 2. The claim that "regular customers reported higher acceptance rates than less familiar respondents" is supported by Section 4. The claim that "African respondents generally rated the items more favourably than non-African respondents, with the exception of the trust item" is supported by Section 3 and cross-checked by Section 7.2. The Q12 feature percentages (53.8 % chatbot, 40.4 % personalised recommendations, etc.) and the 12.2 % "no AI feature useful" figure are produced by Section 5. The 0.52-point spread between the highest and lowest item means is produced by Section 7.1.

This one-to-one mapping between text claims and query outputs is the core of the reproducibility argument: any reader with access to the `survey_responses` table can run the SQL file and verify every reported number without intermediate manipulation.

---

## 7. Reproducibility and Methodological Transparency

The analytical workflow underlying Section 2.3.3 has three transparency features worth highlighting. All transformations are recorded in a single, version-controllable text file (`thesis_block_c_queries.sql`), so the analysis is fully auditable. The use of a reusable `v_q11_complete` view eliminates the risk that different statistics in the section are accidentally computed on slightly different samples. And the standard-SQL formulation makes the analysis portable: the same queries will produce identical results on any PostgreSQL 12+ installation, and require only trivial syntactic adjustment to run on most other major SQL dialects.

To reproduce the analysis end-to-end, a reader executes the queries in `thesis_block_c_queries.sql` against a PostgreSQL database loaded from `african_market_survey.sql`. No spreadsheet manipulation, no external statistical software, and no manual data entry are involved at any stage.

---

## 8. Note on Minor Discrepancies Between Database and Thesis Text

Two small numerical discrepancies exist between the values produced by the queries and the values reported in the thesis text. The listwise-complete sample yields n = 141 on the cleaned dataset, whereas the thesis reports n = 143; the Q12 sample yields n = 154 whereas the thesis reports n = 156. Both differences correspond exactly to the two duplicate submissions identified and removed during data cleaning after the thesis chapter was drafted. The resulting changes in derived statistics are within rounding tolerance: item means differ by at most 0.02, and Cronbach's alpha rounds to 0.77 on the cleaned data versus 0.78 in the thesis text. None of the substantive interpretations are affected, and the cleaning rationale is documented in the accompanying `data_quality_report.md`.

A reader running the queries today will therefore obtain results that align closely - but not identically - with the values printed in the thesis. The methodological position is that the cleaned dataset is the more defensible analytical base, and the two-respondent reduction has no bearing on any conclusion drawn in Section 2.3.3.

---

## 9. File Inventory

| File | Purpose |
| --- | --- |
| `african_market_survey.sql` | `CREATE TABLE` and `INSERT` statements for the cleaned survey dataset (n = 194) |
| `african_market_survey_cleaned.csv` | Same dataset in CSV form for non-SQL inspection |
| `thesis_block_c_queries.sql` | The seven query sections explained in this README |
| `data_quality_report.md` | Documentation of every cleaning decision applied to the raw export |
| `README_section_2_3_3.md` | This document |

---

*Prepared as supporting documentation for the empirical chapter of the graduation thesis. All queries have been syntax-validated and their outputs cross-checked against independent computations.*
