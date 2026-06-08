-- teleclinic_Assesment.sql
-- SQLite analysis queries for teleclinic_data.db

-- 1. Show tables in the database
SELECT name
FROM sqlite_master
WHERE type = 'table'
ORDER BY name;

-- 2. Row counts for each table
SELECT 'Consultations' AS table_name, COUNT(*) AS row_count FROM Consultations;
SELECT 'Patients' AS table_name, COUNT(*) AS row_count FROM Patients;
SELECT 'Insurance' AS table_name, COUNT(*) AS row_count FROM Insurance;
SELECT 'Lab' AS table_name, COUNT(*) AS row_count FROM Lab;
SELECT 'Referrals' AS table_name, COUNT(*) AS row_count FROM Referrals;
SELECT 'FollowUps' AS table_name, COUNT(*) AS row_count FROM FollowUps;


-- 16. Join all tables into one reporting table
DROP TABLE IF EXISTS joined_reporting_table;

CREATE TABLE joined_reporting_table AS
SELECT c.consultation_id,
       c.patient_id,
       p.gender,
       p.age_group,
       p.province AS patient_province,
       p.insurance_scheme AS patient_insurance_scheme,
       iagg.insurance_attempts,
       iagg.successful_insurance_attempts,
       lagg.lab_count,
       fagg.followup_count,
       ragg.referral_count,
       c.status,
       c.diagnosis_category,
       c.channel AS consultation_channel
FROM Consultations AS c
LEFT JOIN Patients AS p
       ON c.patient_id = p.patient_id
LEFT JOIN (
       SELECT patient_id,
              COUNT(*) AS insurance_attempts,
              SUM(CASE WHEN success = 'Yes' THEN 1 ELSE 0 END) AS successful_insurance_attempts
       FROM Insurance
       GROUP BY patient_id
) AS iagg
       ON c.patient_id = iagg.patient_id
LEFT JOIN (
       SELECT consultation_id,
              COUNT(*) AS lab_count
       FROM Lab
       GROUP BY consultation_id
) AS lagg
       ON c.consultation_id = lagg.consultation_id
LEFT JOIN (
       SELECT original_consult_id,
              COUNT(*) AS followup_count
       FROM FollowUps
       GROUP BY original_consult_id
) AS fagg
       ON c.consultation_id = fagg.original_consult_id
LEFT JOIN (
       SELECT consultation_id,
              COUNT(*) AS referral_count
       FROM Referrals
       GROUP BY consultation_id
) AS ragg
       ON c.consultation_id = ragg.consultation_id;

SELECT *
FROM joined_reporting_table
ORDER BY consultation_id DESC
LIMIT 100;

-- 18. Audit: consultations with null critical fields
DROP TABLE IF EXISTS critical_cons_nulls;

CREATE TABLE critical_cons_nulls AS
SELECT consultation_id,
       patient_id,
       status,
       call_type,
       diagnosis_category,
       notes_entered,
       icd_code_entered,
       booked_datetime
FROM Consultations
WHERE call_type IS NULL
   OR diagnosis_category IS NULL
   OR notes_entered IS NULL
   OR icd_code_entered IS NULL;

SELECT *
FROM critical_cons_nulls
ORDER BY booked_datetime DESC;

-- 19. Audit summary: counts of null critical fields
SELECT
  SUM(CASE WHEN call_type IS NULL THEN 1 ELSE 0 END) AS null_call_type,
  SUM(CASE WHEN diagnosis_category IS NULL THEN 1 ELSE 0 END) AS null_diagnosis_category,
  SUM(CASE WHEN notes_entered IS NULL THEN 1 ELSE 0 END) AS null_notes_entered,
  SUM(CASE WHEN icd_code_entered IS NULL THEN 1 ELSE 0 END) AS null_icd_code_entered,
  COUNT(*) AS total_consultations
FROM Consultations;

-- 20. Audit: patients with incomplete registration
DROP TABLE IF EXISTS Incomplete_reg;

CREATE TABLE Incomplete_reg AS
SELECT patient_id,
       gender,
       age_group,
       province,
       insurance_scheme,
       registration_complete,
       insurance_validated
FROM Patients
WHERE registration_complete = 'No' ;

SELECT *
FROM Incomplete_reg
ORDER BY patient_id;

-- 21. Audit summary: totals and percentage for critical_cons_nulls
SELECT
  'critical_cons_nulls' AS table_name,
  COUNT(*) AS total_rows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Consultations), 2) AS pct_of_consultations
FROM critical_cons_nulls;

-- 22. Audit summary: totals and percentage for Incomplete_reg
SELECT
  'Incomplete_reg' AS table_name,
  COUNT(*) AS total_rows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Patients), 2) AS pct_of_patients
FROM Incomplete_reg;

-- 23. Audit: completed consultations missing ICD codes
DROP TABLE IF EXISTS icd_missing_completed;

CREATE TABLE icd_missing_completed AS
SELECT consultation_id,
       patient_id,
       status,
       diagnosis_category,
       clinician_type,
       icd_code_entered,
       booked_datetime
FROM Consultations
WHERE status = 'Completed'
  AND (icd_code_entered IS NULL OR icd_code_entered = 'No');

SELECT *
FROM icd_missing_completed
ORDER BY booked_datetime DESC;

-- 24. Audit summary: totals and percentage for icd_missing_completed
SELECT
  'icd_missing_completed' AS table_name,
  COUNT(*) AS total_rows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Consultations WHERE status = 'Completed'), 2) AS pct_of_completed_consultations
FROM icd_missing_completed;

-- 25. Audit: lab results with no clinician review
DROP TABLE IF EXISTS lab_unreviewed;

CREATE TABLE lab_unreviewed AS
SELECT l.lab_id,
       l.consultation_id,
       l.patient_id,
       l.test_type,
       l.result_uploaded,
       l.clinician_viewed,
       l.tat_hours,
       l.requested_datetime
FROM Lab AS l
WHERE l.result_uploaded = 'Yes'
  AND (l.clinician_viewed IS NULL OR l.clinician_viewed = 'No');

SELECT *
FROM lab_unreviewed
ORDER BY requested_datetime DESC;

-- 26. Audit summary: totals and percentage for lab_unreviewed
SELECT
  'lab_unreviewed' AS table_name,
  COUNT(*) AS total_rows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Lab WHERE result_uploaded = 'Yes'), 2) AS pct_of_uploaded_lab_results
FROM lab_unreviewed;

-- 27. Audit: referrals with null authorisation
DROP TABLE IF EXISTS referrals_null_authorisation;

CREATE TABLE referrals_null_authorisation AS
SELECT referral_id,
       consultation_id,
       patient_id,
       receiving_facility,
       authorised,
       initiated_datetime AS referral_date
FROM Referrals
WHERE authorised IS NULL;

SELECT *
FROM referrals_null_authorisation
ORDER BY referral_date DESC;

-- 28. Audit summary: totals and percentage for referrals_null_authorisation
SELECT
  'referrals_null_authorisation' AS table_name,
  COUNT(*) AS total_rows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Referrals), 2) AS pct_of_referrals
FROM referrals_null_authorisation;

-- 29. Metric 1: ICD Code Completion Rate (Completed Consultations)
DROP TABLE IF EXISTS metric_icd_completion_rate;

CREATE TABLE metric_icd_completion_rate AS
SELECT
  COUNT(*) AS numerator,
  (SELECT COUNT(*) FROM Consultations WHERE status = 'Completed') AS denominator,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM Consultations WHERE status = 'Completed'), 0), 2) AS completion_rate_pct
FROM Consultations
WHERE status = 'Completed'
  AND icd_code_entered = 'Yes';

SELECT *
FROM metric_icd_completion_rate;

-- 30. Metric 2: Lab Result Clinician Review Rate
DROP TABLE IF EXISTS metric_lab_clinician_review_rate;

CREATE TABLE metric_lab_clinician_review_rate AS
SELECT
  COUNT(*) AS numerator,
  (SELECT COUNT(*) FROM Lab WHERE result_uploaded = 'Yes') AS denominator,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM Lab WHERE result_uploaded = 'Yes'), 0), 2) AS review_rate_pct
FROM Lab
WHERE result_uploaded = 'Yes'
  AND clinician_viewed = 'Yes';

SELECT *
FROM metric_lab_clinician_review_rate;

-- 31. Metric 3: Consultation Completion Rate
DROP TABLE IF EXISTS metric_consultation_completion_rate;

CREATE TABLE metric_consultation_completion_rate AS
SELECT
  'Overall' AS segment,
  SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS numerator,
  COUNT(*) AS denominator,
  ROUND(100.0 * SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS completion_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN status = 'No-Show' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS no_show_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS cancellation_rate_pct
FROM Consultations
UNION ALL
SELECT
  urban_rural AS segment,
  SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) AS numerator,
  COUNT(*) AS denominator,
  ROUND(100.0 * SUM(CASE WHEN status = 'Completed' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS completion_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN status = 'No-Show' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS no_show_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS cancellation_rate_pct
FROM Consultations
GROUP BY urban_rural;

SELECT *
FROM metric_consultation_completion_rate
ORDER BY segment;

-- 32. Metric 4: Patient Engagement Rate (Follow-up records linked to target diagnoses)
DROP TABLE IF EXISTS metric_patient_engagement_rate;

CREATE TABLE metric_patient_engagement_rate AS
SELECT
  COUNT(*) AS numerator,
  (SELECT COUNT(*)
   FROM Consultations
   WHERE status = 'Completed'
     AND diagnosis_category IN ('Diabetes', 'Hypertension', 'Mental Health')) AS denominator,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*)
                                   FROM Consultations
                                   WHERE status = 'Completed'
                                     AND diagnosis_category IN ('Diabetes', 'Hypertension', 'Mental Health')), 0), 2) AS engagement_rate_pct
FROM FollowUps AS f
JOIN Consultations AS c
  ON f.original_consult_id = c.consultation_id
WHERE c.status = 'Completed'
  AND c.diagnosis_category IN ('Diabetes', 'Hypertension', 'Mental Health');

SELECT *
FROM metric_patient_engagement_rate;

-- 33. Metric 5: Insurance Validation Success Rate
DROP TABLE IF EXISTS metric_insurance_validation_success_rate;

CREATE TABLE metric_insurance_validation_success_rate AS
SELECT
  COUNT(*) AS numerator,
  (SELECT COUNT(*) FROM Patients) AS denominator,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM Patients), 0), 2) AS success_rate_pct
FROM Patients
WHERE insurance_validated = 'Yes';

SELECT *
FROM metric_insurance_validation_success_rate;

-- 34. Metric 6: Follow-up by disease
DROP TABLE IF EXISTS metric_followup_by_disease;

CREATE TABLE metric_followup_by_disease AS
SELECT
  c.diagnosis_category AS disease,
  COUNT(*) AS followup_records,
  SUM(CASE WHEN c.status = 'Completed' THEN 1 ELSE 0 END) AS completed_consultations,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*)
                                   FROM Consultations
                                   WHERE status = 'Completed'
                                     AND diagnosis_category = c.diagnosis_category), 0), 2) AS followup_rate_pct
FROM FollowUps AS f
JOIN Consultations AS c
  ON f.original_consult_id = c.consultation_id
WHERE c.status = 'Completed'
  AND c.diagnosis_category IN ('Diabetes', 'Hypertension', 'Mental Health')
GROUP BY c.diagnosis_category
ORDER BY c.diagnosis_category;

SELECT *
FROM metric_followup_by_disease;

-- 35. Audit: patients registration by district
DROP TABLE IF EXISTS patient_registration_by_district;

CREATE TABLE patient_registration_by_district AS
SELECT
  COALESCE(p.province, 'Unknown') AS district,
  COUNT(*) AS registered_patients,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Patients), 2) AS pct_of_registered_patients
FROM Patients AS p
GROUP BY p.province
ORDER BY registered_patients DESC;

SELECT *
FROM patient_registration_by_district;

-- 36. Audit: prescriptions not dispensed
DROP TABLE IF EXISTS prescriptions_not_dispensed;

CREATE TABLE prescriptions_not_dispensed AS
SELECT prescription_id,
       consultation_id,
       patient_id,
       medication_name,
       dispensed,
       dispensed_datetime
FROM Prescriptions
WHERE dispensed = 'No';

SELECT *
FROM prescriptions_not_dispensed
ORDER BY dispensed_datetime DESC;

-- 35. Audit summary: totals and percentage for prescriptions_not_dispensed
SELECT
  'prescriptions_not_dispensed' AS table_name,
  COUNT(*) AS total_rows,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Prescriptions), 2) AS pct_of_prescriptions
FROM prescriptions_not_dispensed;
