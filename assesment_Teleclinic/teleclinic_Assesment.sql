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

-- 3. Consultations by status
SELECT status, COUNT(*) AS count
FROM Consultations
GROUP BY status
ORDER BY count DESC;

-- 4. Top diagnosis categories in consultations
SELECT diagnosis_category, COUNT(*) AS count
FROM Consultations
GROUP BY diagnosis_category
ORDER BY count DESC
LIMIT 10;

-- 5. Patient distribution by province
SELECT province, COUNT(*) AS patient_count
FROM Patients
GROUP BY province
ORDER BY patient_count DESC;

-- 6. Insurance success rate by scheme
SELECT insurance_scheme,
       SUM(CASE WHEN success = 'Yes' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS success_rate,
       COUNT(*) AS attempts
FROM Insurance
GROUP BY insurance_scheme
ORDER BY success_rate DESC;

-- 7. Average lab turnaround time by test type
SELECT test_type,
       AVG(tat_hours) AS avg_tat_hours,
       COUNT(*) AS test_count
FROM Lab
WHERE tat_hours IS NOT NULL
GROUP BY test_type
ORDER BY avg_tat_hours ASC
LIMIT 10;

-- 8. Consultation coverage across linked tables
SELECT 'Consultations with followups' AS metric, COUNT(DISTINCT original_consult_id) AS distinct_consults FROM FollowUps;
SELECT 'Consultations with labs' AS metric, COUNT(DISTINCT consultation_id) AS distinct_consults FROM Lab;
SELECT 'Consultations with referrals' AS metric, COUNT(DISTINCT consultation_id) AS distinct_consults FROM Referrals;

-- 9. Patients registered but insurance not validated
SELECT COUNT(*) AS patients_without_validated_insurance
FROM Patients
WHERE registration_complete = 'Yes'
  AND insurance_validated = 'No';

-- 10. Average follow-up delay by diagnosis category
SELECT diagnosis_category,
       AVG(days_to_followup) AS average_days_to_followup
FROM FollowUps
GROUP BY diagnosis_category
ORDER BY average_days_to_followup ASC
LIMIT 20;

-- 11. Consultations joined with patient demographics
SELECT c.consultation_id,
       c.patient_id,
       p.gender,
       p.age_group,
       p.province,
       c.diagnosis_category,
       c.status,
       c.channel
FROM Consultations AS c
LEFT JOIN Patients AS p
       ON c.patient_id = p.patient_id
ORDER BY c.booked_datetime DESC
LIMIT 20;

-- 12. Lab tests joined with consultation and patient data
SELECT l.lab_id,
       l.consultation_id,
       c.diagnosis_category,
       l.test_type,
       l.tat_hours,
       c.channel AS consultation_channel,
       p.province AS patient_province
FROM Lab AS l
LEFT JOIN Consultations AS c
       ON l.consultation_id = c.consultation_id
LEFT JOIN Patients AS p
       ON l.patient_id = p.patient_id
ORDER BY l.requested_datetime DESC
LIMIT 20;

-- 13. Insurance attempts matched to patient demographics
SELECT i.log_id,
       i.patient_id,
       p.gender,
       p.age_group,
       i.insurance_scheme,
       i.success,
       i.failure_reason
FROM Insurance AS i
LEFT JOIN Patients AS p
       ON i.patient_id = p.patient_id
ORDER BY i.attempt_datetime DESC
LIMIT 20;

-- 14. Consultations with lab status and insurance scheme
SELECT c.consultation_id,
       c.patient_id,
       p.insurance_scheme,
       c.diagnosis_category,
       l.test_type,
       l.result_uploaded,
       c.status
FROM Consultations AS c
LEFT JOIN Patients AS p
       ON c.patient_id = p.patient_id
LEFT JOIN Lab AS l
       ON c.consultation_id = l.consultation_id
ORDER BY c.booked_datetime DESC
LIMIT 30;

-- 15. Insurance success rate for patients with consultations
SELECT p.insurance_scheme,
       SUM(CASE WHEN i.success = 'Yes' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS success_rate,
       COUNT(*) AS attempt_count
FROM Insurance AS i
INNER JOIN Patients AS p
       ON i.patient_id = p.patient_id
INNER JOIN Consultations AS c
       ON i.patient_id = c.patient_id
GROUP BY p.insurance_scheme
ORDER BY success_rate DESC;

-- 16. Join all tables in the database
-- This query connects Consultations, Patients, Insurance, Lab, FollowUps, and Referrals
SELECT c.consultation_id,
       c.patient_id,
       p.gender,
       p.age_group,
       p.province AS patient_province,
       p.insurance_scheme AS patient_insurance_scheme,
       i.log_id AS insurance_log_id,
       i.insurance_scheme AS insurance_attempt_scheme,
       i.success AS insurance_success,
       l.lab_id,
       l.test_type,
       l.tat_hours,
       f.followup_id,
       f.days_to_followup,
       r.referral_id,
       r.receiving_facility,
       c.status,
       c.diagnosis_category,
       c.channel AS consultation_channel
FROM Consultations AS c
LEFT JOIN Patients AS p
       ON c.patient_id = p.patient_id
LEFT JOIN Insurance AS i
       ON c.patient_id = i.patient_id
LEFT JOIN Lab AS l
       ON c.consultation_id = l.consultation_id
LEFT JOIN FollowUps AS f
       ON c.consultation_id = f.original_consult_id
LEFT JOIN Referrals AS r
       ON c.consultation_id = r.consultation_id
ORDER BY c.booked_datetime DESC
LIMIT 50;

-- 17. Aggregated summary join across all tables
SELECT c.consultation_id,
       c.patient_id,
       p.gender,
       p.age_group,
       p.province AS patient_province,
       COUNT(DISTINCT l.lab_id) AS lab_count,
       COUNT(DISTINCT f.followup_id) AS followup_count,
       COUNT(DISTINCT r.referral_id) AS referral_count,
       COUNT(DISTINCT i.log_id) AS insurance_attempts,
       SUM(CASE WHEN i.success = 'Yes' THEN 1 ELSE 0 END) AS successful_insurance_attempts
FROM Consultations AS c
LEFT JOIN Patients AS p
       ON c.patient_id = p.patient_id
LEFT JOIN Lab AS l
       ON c.consultation_id = l.consultation_id
LEFT JOIN FollowUps AS f
       ON c.consultation_id = f.original_consult_id
LEFT JOIN Referrals AS r
       ON c.consultation_id = r.consultation_id
LEFT JOIN Insurance AS i
       ON c.patient_id = i.patient_id
GROUP BY c.consultation_id,
         c.patient_id,
         p.gender,
         p.age_group,
         p.province
ORDER BY c.booked_datetime DESC
LIMIT 50;
