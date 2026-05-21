# Data Quality Report — African Market Customer Survey

**Generated:** 2026-05-21 09:32:43  
**Source:** Google Forms export, raw_survey.csv  
**Purpose:** Customer survey data for VIKO graduation thesis on AI-driven digital marketing for Kartpos UAB (African Market, africanmarket.lt)

## 1. Summary

| Metric | Count |
| --- | --- |
| Raw rows imported | 198 |
| Troll / offensive rows removed | 2 |
| Exact-content duplicate rows removed | 2 |
| **Final valid responses** | **194** |
| Cochran sample-size target (n≥196) | BELOW TARGET — see note in §7 |

## 2. Removed rows

### 2.1 Offensive / troll content
Two responses contained slurs and clearly invalid free-text answers across multiple fields; treated as bad-faith submissions and dropped.

| Timestamp | Reason |
| --- | --- |
| 4/24/2026 20:25:16 | offensive/troll content in free-text fields |
| 4/27/2026 7:35:56 | offensive/troll content in free-text fields |

### 2.2 Duplicate submissions
Two pairs of submissions were identical in every column except for timestamp seconds (9–15 seconds apart), strongly suggesting a double-click on submit. The earlier of each pair was kept; the later was dropped.

| Removed timestamp | Reason |
| --- | --- |
| 4/20/2026 16:09:47 | identical to submission at 4/20/2026 16:09:32 (15s earlier) |
| 4/27/2026 12:08:15 | identical to submission at 4/27/2026 12:08:06 (9s earlier) |

## 3. Field normalizations

### 3.1 African country (Q4b)
Values were standardized to a canonical country name, demonyms folded into country names, and stray whitespace stripped. Duplicate Congos were disambiguated.

| Original | Normalized |
| --- | --- |
| `CRM` | NULL |
| `Cameroon/Ivory Coast` | Cameroon; Côte d'Ivoire |
| `Cameroonian` | Cameroon |
| `Congo` | DR Congo |
| `Congo DR` | DR Congo |
| `Congo RC` | Republic of the Congo |
| `Ghanian` | Ghana |
| `Ivory Coast` | Côte d'Ivoire |
| `Ivory Coast/Cameroon` | Côte d'Ivoire; Cameroon |
| `Nigerian` | Nigeria |
| `Republic of Congo` | Republic of the Congo |
| `no .. asian ( Bangladesh)` | NULL |

### 3.2 Nationality (Q4)
Free-text answers (the question allowed "Other") were folded into broad regional groups in a new `nationality_group` column while preserving the respondent's exact wording in `nationality_detail`. This lets SQL queries aggregate by region without losing the specific nationality.

| Original | Group |
| --- | --- |
| `African European` | African |
| `American` | American |
| `Arab` | Middle Eastern |
| `Asian` | Asian |
| `Asian (Bangladesh)` | Asian |
| `Asian Pakistan` | Asian |
| `Asian Pakistani` | Asian |
| `Assian` | Asian |
| `Australian` | Other |
| `Australian/Spanish` | Other |
| `Bangladeshi` | Asian |
| `Indian` | Asian |
| `Japanese` | Asian |
| `Kazakhstan` | Asian |
| `Middle Eastern` | Middle Eastern |
| `Middle Eastern - Lebanese` | Middle Eastern |
| `Middle eastern` | Middle Eastern |
| `Nigerian American` | American |
| `Pakistan` | Asian |
| `Sri Lanka` | Asian |
| `Turkish` | Middle Eastern |
| `Ukraine` | European (non-Lithuanian) |
| `Ukrainian` | European (non-Lithuanian) |

### 3.3 Occupation (Q3)
Several respondents combined categories (e.g., "studying and working"). These were folded into composite categories (`Student + Working`, `Student + Self-employed`, `Employed + Self-employed`) preserved alongside the original text in `occupation_detail`.

| Original | Normalized |
| --- | --- |
| `Employed and Self Employed` | Employed + Self-employed |
| `Student and working` | Student + Working |
| `Studying and Self employed` | Student + Self-employed |
| `Studying and working` | Student + Working |
| `Working and running a business too` | Employed + Self-employed |
| `Working and studying at the same time` | Student + Working |

### 3.4 Platform usage columns merged
Google Forms' branch logic created two parallel sets of Q8 platform questions (one for respondents who knew of African Market, one for those who did not). Since each respondent only ever filled in one set, the columns were merged into a single set of platform-usage columns:

- `Q8a_Facebook + Q8a_Facebook_2 → platform_use_facebook`
- `Q8b_Instagram + Q8b_Instagram_2 → platform_use_instagram`
- `Q8c_TikTok + Q8c_TikTok_2 → platform_use_tiktok`
- `Q8d_YouTube + Q8d_YouTube_2 → platform_use_youtube`
- `Q8e_WhatsApp + Q8e_WhatsApp_2 → platform_use_whatsapp`
- `Q8f_Telegram + Q8f_Telegram_2 → platform_use_telegram`

### 3.5 Multi-select fields exploded into booleans
Comma-separated multi-select answers were exploded into one boolean column per option, which is far more SQL-friendly than parsing comma-delimited strings at query time. A `1` means the respondent selected that option, `0` means they answered the question but did not select it, and `NULL` means they were skipped past the question by branch logic.

**Q12_AIFeatures** → `q12_chatbot`, `q12_personalised_rec`, `q12_auto_notif`, `q12_ai_recipes`, `q12_smart_search`, `q12_ai_promotions`, `q12_none`

**Q15_EngagingContent** → `q15_product_showcases`, `q15_recipes_tutorials`, `q15_cultural_stories`, `q15_promotions_sales`, `q15_customer_reviews`, `q15_behind_the_scenes`, `q15_educational`

**Q16_CommChannels** → `q16_social_media`, `q16_email`, `q16_whatsapp_telegram`, `q16_sms`, `q16_no_comms`

**Q17_Difficulties** → `q17_limited_range`, `q17_info_hard_to_find`, `q17_no_online_order`, `q17_poor_website`, `q17_poor_communication`, `q17_language_barriers`, `q17_none`, `q17_other`

### 3.6 Timestamp normalization
All timestamps converted from US-style `M/D/YYYY H:M:S` to ISO 8601 (`YYYY-MM-DDTHH:MM:SS`) for unambiguous sorting and SQL `TIMESTAMP` compatibility.

### 3.7 Categorical code + label split
Every single-select Likert / multiple-choice field was split into a `_code` column (the original letter, e.g., `a`, `b`, `c`) and a `_label` column (the clean text, e.g., `Male`, `Female`). Use `_code` for joins and ordered analysis, `_label` for human-readable reporting.

## 4. Likert validation

All Likert values fell within the valid 1–5 range; no coercions needed.

## 5. Missing values

Missingness in this dataset is **almost entirely structural** — driven by Google Forms' branch logic:

- Q7, Q8a–f, Q9, Q10, Q11, Q13, Q14, Q15, Q16, Q17 were only shown to respondents who indicated familiarity with African Market in Q6.
- Q4b was only shown to respondents who selected "African" or who otherwise indicated an African country.
- Q10 was only shown to respondents who answered "Yes" to Q9.

Final missing-value count per column:

| Column | NULLs |
| --- | ---: |
| occupation_detail | 184 |
| nationality_detail | 160 |
| Q8d_YouTube_2 | 157 |
| Q8a_Facebook_2 | 156 |
| Q8b_Instagram_2 | 156 |
| Q8c_TikTok_2 | 156 |
| Q8e_WhatsApp_2 | 156 |
| Q8f_Telegram_2 | 156 |
| Q18_Improvement | 110 |
| Q4b_AfricanCountry_normalized | 99 |
| Q4b_AfricanCountry | 97 |
| Q10_WebsiteRating | 95 |
| Q11b_Chatbot | 52 |
| Q11c_TrustAI | 52 |
| Q11e_AIRecipes | 52 |
| Q11d_AutoNotif | 51 |
| Q8a_Facebook | 49 |
| Q11a_PersRec | 49 |
| Q8c_TikTok | 48 |
| Q8f_Telegram | 48 |
| Q17_Difficulties | 47 |
| q17_limited_range | 47 |
| q17_info_hard_to_find | 47 |
| q17_no_online_order | 47 |
| q17_poor_website | 47 |
| q17_poor_communication | 47 |
| q17_language_barriers | 47 |
| q17_none | 47 |
| q17_other | 47 |
| Q8d_YouTube | 45 |
| Q8b_Instagram | 44 |
| Q8e_WhatsApp | 44 |
| Q15_EngagingContent | 44 |
| q15_product_showcases | 44 |
| q15_recipes_tutorials | 44 |
| q15_cultural_stories | 44 |
| q15_promotions_sales | 44 |
| q15_customer_reviews | 44 |
| q15_behind_the_scenes | 44 |
| q15_educational | 44 |
| Q16_CommChannels | 41 |
| q16_social_media | 41 |
| q16_email | 41 |
| q16_whatsapp_telegram | 41 |
| q16_sms | 41 |
| q16_no_comms | 41 |
| Q12_AIFeatures | 40 |
| q12_chatbot | 40 |
| q12_personalised_rec | 40 |
| q12_auto_notif | 40 |
| q12_ai_recipes | 40 |
| q12_smart_search | 40 |
| q12_ai_promotions | 40 |
| q12_none | 40 |
| Q7_HeardFrom | 39 |
| Q13_SocialAdPurchase | 39 |
| Q14_OnlineGrocery | 39 |
| Q7_HeardFrom_code | 39 |
| Q7_HeardFrom_label | 39 |
| Q13_SocialAdPurchase_code | 39 |
| Q13_SocialAdPurchase_label | 39 |
| Q14_OnlineGrocery_code | 39 |
| Q14_OnlineGrocery_label | 39 |
| Q9_VisitedWebsite | 38 |
| Q9_VisitedWebsite_code | 38 |
| Q9_VisitedWebsite_label | 38 |
| Q4_Nationality_code | 34 |
| platform_use_facebook | 11 |
| Q3_Occupation_code | 10 |
| platform_use_tiktok | 10 |
| platform_use_telegram | 10 |
| platform_use_youtube | 8 |
| platform_use_instagram | 6 |
| platform_use_whatsapp | 6 |
| Q5_VisitReason_code | 2 |

## 6. Assumptions

- Q4b "Congo" (bare, no qualifier) resolved to DR Congo (Democratic Republic of the Congo) as it is the more populous Congo with a larger Lithuanian diaspora; "Congo RC" / "Republic of Congo" preserved separately as Republic of the Congo.
- Q4b "CRM" was treated as an invalid response (unknown abbreviation) and converted to NULL.
- Q4b "no .. asian (Bangladesh)" was treated as a non-African response and converted to NULL in the African-country column (the respondent's actual nationality is captured in nationality_detail).
- Duplicate submissions were de-duplicated using full-row content equality (excluding `Timestamp`). The earlier submission in each pair was retained.
- Troll detection used a small offensive-language wordlist applied case-insensitively to the free-text demographic fields (`Q3`, `Q4`, `Q4b`, `Q5`, `Q7`, `Q18`). All matched rows had clearly invalid data in *every* field, supporting removal rather than partial cleaning.
- Multi-select boolean columns use `0` (option not chosen but question answered) versus `NULL` (question skipped). This preserves a meaningful distinction for SQL aggregations.
- All free-text "Other: ___" responses that were not captured in a follow-up text field could not be recovered from the export; treated as a binary "Other" selection only.

## 7. Sample-size note for the thesis

After removing 2 troll rows and 2 duplicate submissions, the final valid n = **194**, which is **2 short of the Cochran target of n ≥ 196**.

For the thesis, you have three reasonable options:
1. **Report and justify.** State in the methodology that 198 responses were collected, 4 were excluded as invalid (duplicates + bad-faith submissions), and the analytic sample is n = 194. The implied margin of error at 95% CI rises only marginally (from ~7.0% to ~7.04%) — this is defensible and transparent.
2. **Collect a small top-up batch.** Add ~5–10 more responses to clear the n ≥ 196 threshold cleanly.
3. **Reframe the target.** Use the achieved sample to recompute the realised confidence interval and report that instead of the a priori target.

Option 1 is the most academically honest and is normally what supervisors expect. The exclusions are well-documented and defensible.

## 8. Output files

| File | Purpose |
| --- | --- |
| `african_market_survey_cleaned.csv` | Clean, analysis-ready CSV (UTF-8) |
| `african_market_survey_cleaned.xlsx` | Same data in Excel format |
| `african_market_survey.sql` | SQLite/PostgreSQL-compatible `CREATE TABLE` + batched `INSERT` statements |
| `data_quality_report.md` | This report |
