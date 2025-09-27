from db_client import get_conn
import datetime as dt

def test_add():
    conn = get_conn()
    cur = conn.cursor()

    # OUT param placeholder = 0
    args = (1, dt.datetime(2025,9,30,19,0,0), 2, "Window seat", 0)
    res = cur.callproc("AddBooking", args)
    booking_id = res[-1]
    print("AddBooking -> booking_id:", booking_id)
    cur.close(); conn.close()

def test_update(booking_id):
    conn = get_conn(); cur = conn.cursor()
    args = (booking_id, dt.datetime(2025,9,30,20,0,0), 2, "Changed time", 0)
    res = cur.callproc("UpdateBooking", args)
    success = res[-1]
    print("UpdateBooking -> success:", success)
    cur.close(); conn.close()

def test_cancel(booking_id):
    conn = get_conn(); cur = conn.cursor()
    args = (booking_id, 0)
    res = cur.callproc("CancelBooking", args)
    success = res[-1]
    print("CancelBooking -> success:", success)
    cur.close(); conn.close()

def test_getmax():
    conn = get_conn(); cur = conn.cursor()
    args = (0,)
    res = cur.callproc("GetMaxQuantity", args)
    maxq = res[-1]
    print("GetMaxQuantity ->", maxq)
    cur.close(); conn.close()

if __name__ == "__main__":
    test_add()
    # بدّل بالقيمة المطبوعة من الإضافة:
    # test_update(booking_id=1)
    # test_cancel(booking_id=1)
    test_getmax()
