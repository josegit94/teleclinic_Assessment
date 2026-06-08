"""
TeleClinic Platform — Month 3 Analysis
Data Analyst & MEL Associate Candidate Assessment
Author: Nyarwaya Joseph Revocatus
Tools: Python 3, pandas, numpy
"""

import pandas as pd
import numpy as np

# ============================================================
# 0. LOAD DATA
# ============================================================

xl = pd.read_excel(
    '/mnt/user-data/uploads/Copy_of_TeleClinic_Candidate_Dataset_Month3.xlsx',
    sheet_name=None
)

patients      = xl['👥 Patients']
consults      = xl['📅 Consultations']
followups     = xl['🔁 Follow-Ups']
labs          = xl['🧪 Lab Tests']
prescriptions = xl['💊 Prescriptions']
referrals     = xl['↗️ Referrals']
insurance     = xl['🔐 Insurance Log']

print("=== TABLE SHAPES ===")
for name, df in xl.items():
    print(f"  {name}: {df.shape}")

# Derived subset used throughout
completed = consults[consults['status'] == 'Completed']

# ============================================================
# 1. DATA QUALITY AUDIT
# ============================================================

print("\n\n=== PART 1: DATA QUALITY AUDIT ===")

# Issue 01 — 307 null clinical rows
print("\n--- Issue 01: Null clinical fields ---")
null_consults = consults[consults['diagnosis_category'].isnull()]
print(f"Rows with null diagnosis_category: {len(null_consults)}")
print(f"Status breakdown: {null_consults['status'].value_counts().to_dict()}")

# Issue 02 — Incomplete registration
print("\n--- Issue 02: Incomplete registration ---")
incomplete = patients[patients['registration_complete'] == 'No']
print(f"Incomplete registrations: {len(incomplete)}")
# Perfect concordance check
mismatch = patients[patients['registration_complete'] != patients['insurance_validated']]
print(f"Reg_complete / ins_validated mismatches: {len(mismatch)}")
# None of the incomplete patients appear in consultations
inc_in_consults = consults[consults['patient_id'].isin(incomplete['patient_id'])]
print(f"Incomplete-reg patients with any consultation: {len(inc_in_consults)}")

# Issue 03 — ICD code compliance
print("\n--- Issue 03: ICD code compliance ---")
icd_rate = (completed['icd_code_entered'] == 'Yes').mean()
print(f"ICD completion (completed only): {icd_rate:.3f} ({icd_rate*100:.1f}%)")
for ct in ['GP', 'Nurse']:
    sub = completed[completed['clinician_type'] == ct]
    r = (sub['icd_code_entered'] == 'Yes').mean()
    print(f"  {ct}: {r*100:.1f}%  (n={len(sub)})")

# Issue 04 — Lab result review
print("\n--- Issue 04: Lab result review ---")
labs_uploaded = labs[labs['result_uploaded'] == 'Yes']
labs_viewed   = labs_uploaded[labs_uploaded['clinician_viewed'] == 'Yes']
not_uploaded  = labs[labs['result_uploaded'] == 'No']
not_viewed    = labs_uploaded[labs_uploaded['clinician_viewed'] == 'No']
print(f"Tests ordered: {len(labs)}")
print(f"Results uploaded: {len(labs_uploaded)} ({len(labs_uploaded)/len(labs)*100:.1f}%)")
print(f"Not uploaded: {len(not_uploaded)} ({len(not_uploaded)/len(labs)*100:.1f}%)")
print(f"Uploaded but NOT viewed: {len(not_viewed)} ({len(not_viewed)/len(labs_uploaded)*100:.1f}%)")
print(f"Mean hours since upload (unviewed): {not_viewed['tat_hours'].mean():.1f}h")

# Issue 05 — Null referral authorisation
print("\n--- Issue 05: Null referral authorisation ---")
null_auth = referrals[referrals['authorised'].isnull()]
print(f"Referrals with null authorised: {len(null_auth)} ({len(null_auth)/len(referrals)*100:.1f}%)")

# Issue 06 — Patients with no consultations
print("\n--- Issue 06: Patients with no consultations ---")
consult_pats = set(consults['patient_id'])
patient_pats = set(patients['patient_id'])
no_consult   = patient_pats - consult_pats
print(f"Registered patients with no consultation: {len(no_consult)} ({len(no_consult)/len(patients)*100:.1f}%)")

# Issue 07 — Undispensed prescriptions
print("\n--- Issue 07: Undispensed prescriptions ---")
not_dispensed = prescriptions[prescriptions['dispensed'] == 'No']
print(f"Not dispensed: {len(not_dispensed)} / {len(prescriptions)} = {len(not_dispensed)/len(prescriptions)*100:.1f}%")

# JOIN PROBLEM — Musanze logical anomaly
print("\n--- JOIN PROBLEM: Musanze ---")
district_pats = patients.groupby('district').size().rename('patients')
district_comp = completed.groupby('district').size().rename('completed')
df_dist = pd.concat([district_pats, district_comp], axis=1).fillna(0)
df_dist['utilisation_rate'] = (df_dist['completed'] / df_dist['patients'] * 100).round(1)
print(df_dist.sort_values('utilisation_rate', ascending=False).to_string())

# Confirm no orphan records (referential integrity is clean)
orphan_consults = set(consults['patient_id']) - set(patients['patient_id'])
orphan_labs     = set(labs['consultation_id']) - set(consults['consultation_id'])
orphan_rx       = set(prescriptions['consultation_id']) - set(consults['consultation_id'])
orphan_refs     = set(referrals['consultation_id']) - set(consults['consultation_id'])
print(f"\nOrphan check (all should be 0):")
print(f"  Consult patient_ids not in Patients: {len(orphan_consults)}")
print(f"  Lab consult_ids not in Consultations: {len(orphan_labs)}")
print(f"  Rx consult_ids not in Consultations: {len(orphan_rx)}")
print(f"  Referral consult_ids not in Consultations: {len(orphan_refs)}")

# ============================================================
# 2. METRICS & ANALYSIS
# ============================================================

print("\n\n=== PART 2: METRICS ===")

# Metric 1 — ICD completion rate
print("\n--- Metric 1: ICD Code Completion ---")
n_completed = len(completed)
n_icd = (completed['icd_code_entered'] == 'Yes').sum()
print(f"ICD completion rate: {n_icd}/{n_completed} = {n_icd/n_completed*100:.1f}%")

# Metric 2 — Lab result review rate
print("\n--- Metric 2: Lab Result Review Rate ---")
review_rate = len(labs_viewed) / len(labs_uploaded)
full_pipeline = len(labs_viewed) / len(labs)
print(f"Review rate (of uploaded): {review_rate*100:.1f}%")
print(f"Full pipeline (ordered → viewed): {full_pipeline*100:.1f}%")

# Metric 3 — Consultation completion rate + rural/urban breakdown
print("\n--- Metric 3: Consultation Completion Rate ---")
total_consults = len(consults)
comp_rate = n_completed / total_consults
no_show_rate  = (consults['status'] == 'No-Show').sum() / total_consults
cancel_rate   = (consults['status'] == 'Cancelled').sum() / total_consults
print(f"Completion rate: {comp_rate*100:.1f}%")
print(f"No-show rate:    {no_show_rate*100:.1f}%")
print(f"Cancellation:    {cancel_rate*100:.1f}%")
for grp in ['Rural', 'Urban']:
    sub = consults[consults['urban_rural'] == grp]
    r = (sub['status'] == 'Completed').sum() / len(sub)
    print(f"  {grp}: {r*100:.1f}%")

# Metric 4 — Chronic disease follow-up rate
print("\n--- Metric 4: Chronic Disease Follow-Up Rate ---")
chronic_dx = ['Diabetes', 'Hypertension', 'Mental Health']
followup_ids = set(followups['original_consult_id'])
for dx in chronic_dx:
    total_dx = len(completed[completed['diagnosis_category'] == dx])
    fu_dx    = len(followups[followups['diagnosis_category'] == dx])
    print(f"  {dx}: {fu_dx}/{total_dx} = {fu_dx/total_dx*100:.1f}%")

all_chronic = len(completed[completed['diagnosis_category'].isin(chronic_dx)])
all_fu      = len(followups[followups['diagnosis_category'].isin(chronic_dx)])
print(f"  Combined: {all_fu}/{all_chronic} = {all_fu/all_chronic*100:.1f}%")

# Metric 5 — Insurance validation rate
print("\n--- Metric 5: Insurance Validation Rate ---")
val_rate = (patients['insurance_validated'] == 'Yes').mean()
print(f"Validation rate: {val_rate*100:.1f}%")
print("Failure reasons:")
failures = insurance[insurance['success'] == 'No']
print(failures['failure_reason'].value_counts(normalize=True).mul(100).round(1).to_dict())

# ============================================================
# 3. EQUITY ANALYSIS
# ============================================================

print("\n\n=== PART 3: EQUITY ===")

# Equity Measure 1 — Coverage Parity Index
rural_share = (patients['urban_rural'] == 'Rural').mean()
NATIONAL_RURAL = 0.83
CPI = rural_share / NATIONAL_RURAL
print(f"\nCoverage Parity Index: {rural_share:.3f} / {NATIONAL_RURAL} = {CPI:.3f}")
print(f"Rural enrolment: {rural_share*100:.1f}% vs national {NATIONAL_RURAL*100:.1f}%")
print(f"Gap: {(NATIONAL_RURAL - rural_share)*100:.1f} pp shortfall")

# Equity Measure 2 — Uninsured completion deficit
print("\n--- Equity Measure 2: Uninsured Completion Deficit ---")
uninsured_consults = consults[consults['insurance_scheme'] == 'Uninsured']
insured_consults   = consults[consults['insurance_scheme'] != 'Uninsured']
unins_comp = (uninsured_consults['status'] == 'Completed').mean()
ins_comp   = (insured_consults['status'] == 'Completed').mean()
print(f"Insured completion:   {ins_comp*100:.1f}%")
print(f"Uninsured completion: {unins_comp*100:.1f}%")
print(f"Gap: {(ins_comp - unins_comp)*100:.1f} pp")

# Insurance validation by scheme
print("\nValidation rate by insurance scheme:")
for scheme in patients['insurance_scheme'].unique():
    sub = patients[patients['insurance_scheme'] == scheme]
    vr  = (sub['insurance_validated'] == 'Yes').mean()
    print(f"  {scheme}: {vr*100:.1f}%  (n={len(sub)})")

# Channel equity
print("\nCompletion rate by channel:")
for ch in consults['channel'].dropna().unique():
    sub = consults[consults['channel'] == ch]
    r   = (sub['status'] == 'Completed').mean()
    pct_rural = (patients[patients['channel'] == ch]['urban_rural'] == 'Rural').mean()
    print(f"  {ch}: {r*100:.1f}% completion · {pct_rural*100:.1f}% rural")

# Gender equity
print("\nGender equity:")
for g in ['Male', 'Female']:
    sub  = consults[consults['gender'] == g]
    comp = (sub['status'] == 'Completed').mean()
    ref_pats = set(referrals['patient_id'])
    comp_sub  = completed[completed['gender'] == g]
    ref_rate  = comp_sub['patient_id'].isin(ref_pats).mean()
    print(f"  {g}: completion {comp*100:.1f}% · referral rate {ref_rate*100:.1f}%")

# ============================================================
# 4. DASHBOARD INPUT COMPILATION
# ============================================================

print("\n\n=== PART 4: DASHBOARD DATA SUMMARY ===")
print(f"Safety: unreviewed lab results: {len(not_viewed)}")
print(f"Safety: labs not uploaded: {len(not_uploaded)}")
print(f"Safety: referrals pending: {len(null_auth)}")
print(f"Quality: ICD completion: {n_icd/n_completed*100:.1f}%")
print(f"Quality: completion rate: {comp_rate*100:.1f}%")
print(f"Quality: lab review rate: {review_rate*100:.1f}%")
print(f"Quality: Rx dispensing: {(prescriptions['dispensed']=='Yes').mean()*100:.1f}%")
print(f"Equity: CPI = {CPI:.3f}")
print(f"Equity: uninsured gap = {(ins_comp-unins_comp)*100:.1f} pp")

# ============================================================
# 5. WEEKLY VOLUME TREND (for sparkline)
# ============================================================

print("\n\n=== WEEKLY VOLUME TREND ===")
weekly_total = consults.groupby('week_number').size()
weekly_comp  = completed.groupby('week_number').size()
weekly_rate  = (weekly_comp / weekly_total * 100).round(1)
summary = pd.DataFrame({
    'total': weekly_total,
    'completed': weekly_comp,
    'completion_pct': weekly_rate
})
print(summary.to_string())

print("\n\nAnalysis complete.")