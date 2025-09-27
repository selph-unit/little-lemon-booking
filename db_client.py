import os
import mysql.connector as mc

def get_conn():
    return mc.connect(
        host=os.getenv("DB_HOST","127.0.0.1"),
        user=os.getenv("DB_USER","root"),
        password=os.getenv("DB_PASS",""),
        database=os.getenv("DB_NAME","little_lemon"),
        autocommit=True
    )

def call_proc(conn, name, args, out_count=0):
    cur = conn.cursor()
    cur.callproc(name, args)
    # جلب قيم OUT
    outs = []
    for result in cur.stored_results():
        result.fetchall()  # تنظيف
    # بعد callproc، القيم ترجع في args المعدّلة
    cur.close()
    return args
