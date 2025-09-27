# export_to_csv.py
"""
Export Little Lemon MySQL tables to CSV files in ./exports/

Usage:
    python export_to_csv.py
"""

import os
from pathlib import Path
import sys

import pandas as pd
import mysql.connector as mc

# إعدادات الاتصال
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASS", "1234"),
    "database": os.getenv("DB_NAME", "little_lemon"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "autocommit": True,
}

# الجداول المطلوب تصديرها
TABLES = [
    "Customers",
    "RestaurantTables",
    "Bookings",
    "MenuItems",
    "Orders",
    "OrderItems",
]

# إنشاء مجلد exports إذا غير موجود
EXPORT_DIR = Path(__file__).resolve().parent / "exports"
EXPORT_DIR.mkdir(parents=True, exist_ok=True)


def export_table(table_name, conn):
    """تصدير جدول واحد إلى CSV"""
    try:
        query = f"SELECT * FROM `{table_name}`"
        df = pd.read_sql(query, conn)
        out_file = EXPORT_DIR / f"{table_name}.csv"
        df.to_csv(out_file, index=False, encoding="utf-8-sig")
        print(f"✅ Exported {table_name} -> {out_file}")
    except Exception as e:
        print(f"⚠️ Failed {table_name}: {e}")


def main():
    print(">>> Little Lemon — Export to CSV")
    try:
        conn = mc.connect(**DB_CONFIG)
    except mc.Error as err:
        print("✖ Cannot connect to MySQL server.")
        print("Error:", err)
        sys.exit(1)

    for table in TABLES:
        export_table(table, conn)

    conn.close()
    print("\nAll done. Check the 'exports' folder for your CSV files.")


if __name__ == "__main__":
    main()
