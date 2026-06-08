import sqlite3
from datetime import datetime
from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
DB_FILE = BASE_DIR / 'teleclinic_data.db'
SQL_FILE = BASE_DIR / 'teleclinic_Assesment.sql'
REPORT_FILE = BASE_DIR / 'audit_report_generated.xlsx'

METRIC_TABLES = [
    'metric_icd_completion_rate',
    'metric_lab_clinician_review_rate',
    'metric_consultation_completion_rate',
    'metric_patient_engagement_rate',
    'metric_insurance_validation_success_rate',
    'metric_followup_by_disease',
]

METRIC_SHEET_NAMES = {
    'metric_icd_completion_rate': 'Metric_ICD',
    'metric_lab_clinician_review_rate': 'Metric_LabReview',
    'metric_consultation_completion_rate': 'Metric_Completion',
    'metric_patient_engagement_rate': 'Metric_Engagement',
    'metric_insurance_validation_success_rate': 'Metric_Insurance',
    'metric_followup_by_disease': 'Metric_FollowUpByDisease',
}

AUDIT_TABLES = [
    'critical_cons_nulls',
    'Incomplete_reg',
    'icd_missing_completed',
    'lab_unreviewed',
    'referrals_null_authorisation',
    'patient_registration_by_district',
    'prescriptions_not_dispensed',
    'joined_reporting_table',
]


def safe_count(conn: sqlite3.Connection, table_name: str) -> int:
    try:
        return pd.read_sql_query(f'SELECT COUNT(*) AS total_rows FROM {table_name}', conn).iloc[0, 0]
    except Exception:
        return 0


def export_audit_tables_to_excel(db_path: Path, sql_path: Path, report_path: Path, metric_tables: list[str], audit_tables: list[str]) -> None:
    """Create the SQL tables, then export the five metrics and the audit tables into clean Excel sheets."""
    with sqlite3.connect(db_path) as conn:
        sql_text = sql_path.read_text(encoding='utf-8')
        for statement in [part.strip() for part in sql_text.split(';') if part.strip()]:
            try:
                conn.execute(statement)
            except Exception as exc:
                print(f'Skipping SQL statement: {exc}')

        metric_sheets = []
        for table_name in metric_tables:
            try:
                df = pd.read_sql_query(f'SELECT * FROM {table_name}', conn)
            except Exception as exc:
                print(f'Skipping metric table {table_name}: {exc}')
                continue

            summary_df = pd.DataFrame([{
                'metric_table': table_name,
                'numerator': df.iloc[0, 0] if 'numerator' in df.columns else None,
                'denominator': df.iloc[0, 1] if len(df.columns) > 1 else None,
                'rate_pct': df.iloc[0, 2] if len(df.columns) > 2 else None,
            }])
            metric_sheets.append((table_name, df, summary_df))

        audit_sheets = []
        for table_name in audit_tables:
            try:
                df = pd.read_sql_query(f'SELECT * FROM {table_name}', conn)
            except Exception as exc:
                print(f'Skipping audit table {table_name}: {exc}')
                continue

            total_rows = safe_count(conn, table_name)
            pct_of_base = None
            if table_name == 'critical_cons_nulls':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Consultations), 2) AS pct_of_base FROM critical_cons_nulls', conn).iloc[0, 0]
            elif table_name == 'Incomplete_reg':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Patients), 2) AS pct_of_base FROM Incomplete_reg', conn).iloc[0, 0]
            elif table_name == 'icd_missing_completed':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Consultations WHERE status = "Completed"), 2) AS pct_of_base FROM icd_missing_completed', conn).iloc[0, 0]
            elif table_name == 'lab_unreviewed':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Lab WHERE result_uploaded = "Yes"), 2) AS pct_of_base FROM lab_unreviewed', conn).iloc[0, 0]
            elif table_name == 'referrals_null_authorisation':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Referrals), 2) AS pct_of_base FROM referrals_null_authorisation', conn).iloc[0, 0]
            elif table_name == 'patient_registration_by_district':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Patients), 2) AS pct_of_base FROM patient_registration_by_district', conn).iloc[0, 0]
            elif table_name == 'prescriptions_not_dispensed':
                pct_of_base = pd.read_sql_query('SELECT ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Prescriptions), 2) AS pct_of_base FROM prescriptions_not_dispensed', conn).iloc[0, 0]

            summary_df = pd.DataFrame([
                {'table_name': table_name, 'total_rows': total_rows, 'pct_of_base': pct_of_base}
            ])
            audit_sheets.append((table_name, df, summary_df))

        if metric_sheets or audit_sheets:
            target_path = report_path
            if target_path.exists():
                try:
                    target_path.unlink()
                except PermissionError:
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    target_path = target_path.with_name(f'{target_path.stem}_{timestamp}{target_path.suffix}')
            with pd.ExcelWriter(target_path, engine='openpyxl', mode='w') as writer:
                for table_name, df, summary_df in metric_sheets:
                    sheet_name = METRIC_SHEET_NAMES.get(table_name, table_name[:31])
                    df.to_excel(writer, index=False, sheet_name=sheet_name)
                    summary_df.to_excel(writer, startrow=len(df) + 3, index=False, sheet_name=sheet_name)
                for table_name, df, summary_df in audit_sheets:
                    df.to_excel(writer, index=False, sheet_name=table_name)
                    summary_df.to_excel(writer, startrow=len(df) + 3, index=False, sheet_name=table_name)
            print(f'Excel report saved to {target_path}')
        else:
            print('No metric or audit tables were found to export.')


if __name__ == '__main__':
    export_audit_tables_to_excel(DB_FILE, SQL_FILE, REPORT_FILE, METRIC_TABLES, AUDIT_TABLES)
