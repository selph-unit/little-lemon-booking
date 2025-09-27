from db_client import get_conn
import datetime as dt

def manage(action, customer_id=None, booking_id=None, when=None, guests=None, notes=None):
    conn = get_conn(); cur = conn.cursor()
    args = (action, customer_id or 0, booking_id or 0, when, guests or 0, notes, 0)
    res = cur.callproc("ManageBooking", args)
    code = res[-1]
    cur.close(); conn.close()
    return code

if __name__ == "__main__":
    code = manage(
        action='ADD',
        customer_id=1,
        when=dt.datetime(2025,10,1,19,30,0),
        guests=4,
        notes="Near bar"
    )
    print("ManageBooking(ADD) ->", code)
