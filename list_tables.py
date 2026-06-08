import sqlite3
conn = sqlite3.connect('teleclinic_data.db')
print([r[0] for r in conn.execute('SELECT name FROM sqlite_master WHERE type="table" ORDER BY name')])
conn.close()
