CREATE TABLE public.survey_responses (
    response_id SERIAL PRIMARY KEY,

    submission_time TIMESTAMP,

    gender VARCHAR(20),

    age_group VARCHAR(30),

    nationality_group VARCHAR(50),

    residence_status VARCHAR(50),

    familiarity_african_market VARCHAR(100),

    shopping_frequency VARCHAR(100),

    preferred_channel VARCHAR(100),

    satisfaction_customer_service INTEGER CHECK (satisfaction_customer_service BETWEEN 1 AND 5),

    satisfaction_product_availability INTEGER CHECK (satisfaction_product_availability BETWEEN 1 AND 5),

    satisfaction_delivery_speed INTEGER CHECK (satisfaction_delivery_speed BETWEEN 1 AND 5),

    satisfaction_social_media INTEGER CHECK (satisfaction_social_media BETWEEN 1 AND 5),

    q11a_personalised_recommendations INTEGER CHECK (q11a_personalised_recommendations BETWEEN 1 AND 5),

    q11b_ai_chatbot INTEGER CHECK (q11b_ai_chatbot BETWEEN 1 AND 5),

    q11c_trust_ai_content INTEGER CHECK (q11c_trust_ai_content BETWEEN 1 AND 5),

    q11d_automated_notifications INTEGER CHECK (q11d_automated_notifications BETWEEN 1 AND 5),

    q11e_ai_recipe_suggestions INTEGER CHECK (q11e_ai_recipe_suggestions BETWEEN 1 AND 5),

    q12_ai_features TEXT,

    additional_comments TEXT
);


SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'survey_responses'
ORDER BY ordinal_position;

CREATE TABLE public.thesis_analysis AS
SELECT
    response_id,
    nationality_group,
    familiarity_african_market,
    q11a_personalised_recommendations,
    q11b_ai_chatbot,
    q11c_trust_ai_content,
    q11d_automated_notifications,
    q11e_ai_recipe_suggestions,
    q12_ai_features
FROM public.survey_responses;

SELECT COUNT(*) AS total_records
FROM public.survey_responses;

SELECT COUNT(*) AS complete_q11_cases
FROM public.survey_responses
WHERE q11a_personalised_recommendations IS NOT NULL
  AND q11b_ai_chatbot IS NOT NULL
  AND q11c_trust_ai_content IS NOT NULL
  AND q11d_automated_notifications IS NOT NULL
  AND q11e_ai_recipe_suggestions IS NOT NULL;

  SELECT DISTINCT q11a_personalised_recommendations
FROM public.survey_responses
ORDER BY 1;