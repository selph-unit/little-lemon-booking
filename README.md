# Little Lemon Booking Project
This project implements a restaurant reservation system for **Little Lemon** using **MySQL** for database storage and schema design, **Python** for data interaction, booking management, and CSV export, and **Tableau** for data visualization and reporting.

## Project Structure
little-lemon-booking/
├── sql/
│   └── little_lemon_schema.sql       # Database schema (tables, indexes, sample data)
├── python/
│   ├── db_client.py                  # Connects to MySQL database
│   ├── manage_booking.py             # Insert/update/cancel bookings
│   ├── export_to_csv.py              # Export booking data to CSV
│   └── test_bookings.py              # Testing script with sample bookings
├── little_lemon_bookings_full.csv    # Exported data for Tableau
└── README.md                         # Project documentation

## Setup Instructions
1. Database  
Run the SQL schema:  
mysql -u root -p < sql/little_lemon_schema.sql  

2. Python Client  
Install required Python packages:  
pip install mysql-connector-python pandas  

Run scripts:  
python python/db_client.py  
python python/manage_booking.py  
python python/export_to_csv.py  

This will generate `little_lemon_bookings_full.csv`.  

3. Tableau  
Import `little_lemon_bookings_full.csv` into Tableau Public and build dashboards using the exported booking data.

## Tableau Dashboards
Three dashboards were created:  
1. Daily Bookings → Number of bookings per day, color-coded by status (Booked, Completed, Cancelled).  
2. Table Utilization → Bar chart showing total minutes each table is used.  
3. Cancellation Rate → Line chart showing the percentage of cancelled bookings across days.

## Example Dashboard
![Dashboard Example](screenshot.png)

## Deliverables
- SQL schema for the booking system  
- Python scripts for database interaction and CSV export  
- Full CSV dataset for Tableau  
- Tableau dashboards for analysis
