import os
import sqlite3
import pandas as pd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(BASE_DIR, 'teleclinic_data.db')

CSV_FILES = {
    'Patients': 'Patients_Candidate_Dataset_Month3.csv',
    'FollowUps': 'FollowUps_Teleclinic_Candidate_Dataset_Month3.csv',
    'Insurance': 'Insurance_Teleclinic_Candidate_Dataset_Month3.csv',
    'Lab': 'Lab_Teleclinic_Candidate_Dataset_Month3.csv',
    'Referrals': 'Referrals_Teleclinic_Candidate_Dataset_Month3.csv',
    'Consultations': 'Consultations_Candidate_Dataset_Month3.csv',
}


def load_csv_to_sqlite(db_path: str, csv_map: dict[str, str], base_dir: str) -> None:
    """Load CSV files into a SQLite database with one table per CSV."""
    with sqlite3.connect(db_path) as conn:
        for table_name, file_name in csv_map.items():
            csv_path = os.path.join(base_dir, file_name)
            print(f'Loading {csv_path} into table {table_name}...')
            df = pd.read_csv(csv_path)
            df.to_sql(table_name, conn, if_exists='replace', index=False)
        print(f'Data successfully written to {db_path}')


if __name__ == '__main__':
    load_csv_to_sqlite(DB_FILE, CSV_FILES, BASE_DIR)

