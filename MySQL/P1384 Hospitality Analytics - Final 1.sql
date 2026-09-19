select count(booking_id) from fact_bookings;
select count(property_id) from fact_aggregated_bookings;
select count(date) from dim_date;
select * from fact_bookings;
select * from fact_aggregated_bookings;
select * from dim_date;
select * from dim_hotels;
select * from dim_rooms;

--   -----------------  01 Revenue --------------------------- 
select concat(round(sum(revenue_realized)/1000000000,2)," B") as Total_Revenue_₹ from fact_bookings;

--   -----------------  02 Total booking  ------------------- 
select  concat(round(count(booking_id)/1000,2),' K') as Total_Booking 
 from fact_bookings;
 
--   -----------------  03 Total Capacity ---------------------------
select concat(round(sum(capacity)/1000,2), ' K') as Total_Capacity 
from fact_aggregated_bookings;

--   -----------------  04 Total Succesful Bookings -----------------(Its same as Total booking. Have chagned to count) 	
SELECT 
    ROUND(count(successful_bookings),0)
AS total_successful_bookings
FROM fact_aggregated_bookings;

--   -----------------  05 Occupancy % ------------------------------
select concat(round(sum(successful_bookings)/sum(capacity)*100,2), " %") as Occupancy_Per from fact_aggregated_bookings;

--   -----------------  06 Average Rating  --------------------------
select round( avg(nullif(ratings_given,"")),2) as average_rating
from fact_bookings;

--    ----------------- 07 No of Days ----------------------------
SELECT count(distinct(check_in_date)) AS total_days
FROM fact_bookings;

--   -----------------  08 Total cancelled bookings --------------
select count(booking_id) as Total_cancelled_bookings from fact_bookings
where booking_status="Cancelled";

--   -----------------  09 Cancellation % ------------------------
select concat(round(count(case when booking_status="Cancelled" then 1 end)*100/count(*),2)," %") 
as Cancellation_Per from fact_bookings;

--   -----------------  10 Total Checked Out ----------------------
select
count(booking_status)
from fact_bookings
where booking_status='Checked Out';

-- -- ----------------- 11 Total No Show Booking -----------------
SELECT COUNT(*) AS total_no_show_bookings
FROM fact_bookings
WHERE booking_status = 'No Show'; 

-- -- ----------------- 12  No Show rate % -----------------------
SELECT CONCAT(
    ROUND(
        COUNT(DISTINCT CASE
            WHEN booking_status = 'No Show' THEN booking_id
        END) * 100.0
        / COUNT(DISTINCT booking_id),
        2
    ),
    '%'
) AS no_show_rate
FROM fact_bookings;

--   -----------------  13 Booking % by Platform -----------------
select booking_platform, count(*) as "Count of bookings",
concat(round(count(*)*100/(select count(*) from fact_bookings),0), " %") as "Percentage" from fact_bookings
group by booking_platform order by booking_platform asc;

--   -----------------  14 Booking % by Room Class ----------------
select 
    r.room_class,
    count(booking_id) as total_bookings,
     concat(ROUND(
        COUNT(booking_id) * 100.0 /
        (SELECT COUNT(booking_id) FROM fact_bookings),1),' %') as booking_percentage
from fact_bookings as f join dim_rooms as r on r.room_id=f.room_category
group by room_category
order by  booking_percentage desc;

--   -----------------  15 Booking ADR(Average Daily rate) -----------------
SELECT
    ROUND(
        SUM(revenue_realized) / COUNT(booking_id),
        2
    ) AS ADR
FROM fact_bookings;

--   -----------------  16 Realisation % -----------------------------------
SELECT CONCAT(
    ROUND(
        COUNT(DISTINCT CASE
            WHEN booking_status = 'Checked Out' THEN booking_id
        END) * 100.0
        / COUNT(DISTINCT booking_id),
        2
    ),
    '%'
) AS realisation_percentage
FROM fact_bookings;

--   -----------------  17 RevPAR(Revenue Per Available Room) ----
select round(sum(b.revenue_generated)/(select sum(capacity) from fact_aggregated_bookings),0) as RevPAR from fact_bookings as b;

--   -----------------  18  DBRN(Daily Booked Room Nights) -------   
SELECT 
    ROUND(
        COUNT(booking_id) /
        (SELECT COUNT(DISTINCT `date`) FROM dim_date),2) AS DBRN
FROM fact_bookings;

--   -----------------  19 DSRN (Daily Sellable Room Nights) -----

SELECT 
    round(SUM(capacity) / COUNT(DISTINCT check_in_date),2) AS DSRN
FROM fact_aggregated_bookings;    

--   -----------------  20 DURN ----------------------------------
SELECT ROUND(
    COUNT(DISTINCT CASE
        WHEN booking_status = 'Checked Out' THEN booking_id
    END)
    / COUNT(DISTINCT check_in_date),
    2
) AS DURN
FROM fact_bookings;

--   -----------------  21 Revenue WoW change % ------------------
WITH weekly_revenue AS (
    SELECT
        d.week_no,
        SUM(f.revenue_realized) AS revenue
    FROM fact_bookings f
    JOIN dim_date d
        ON f.check_in_date = d.date
    GROUP BY d.week_no
),
revenue_wow AS (
    SELECT
        week_no,
        revenue,
        LAG(revenue) OVER (
            ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED)
        ) AS prev_revenue
    FROM weekly_revenue
)
SELECT
    week_no,
    ROUND(revenue, 0) AS revcw,
    ROUND(prev_revenue, 0) AS revpw,
    CONCAT(
        ROUND(
            (revenue - prev_revenue) * 100.0 / prev_revenue,
            2
        ),
        '%'
    ) AS `Revenue WoW change %`
FROM revenue_wow
ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED);

--   -----------------  22  Occupancy WoW change % ------------------
WITH weekly_occupancy AS (
    SELECT
        d.week_no,
        SUM(a.successful_bookings) * 100.0 / SUM(a.capacity) AS occupancy
    FROM fact_aggregated_bookings a
    JOIN dim_date d
        ON a.check_in_date = d.date
    GROUP BY d.week_no
),
occupancy_wow AS (
    SELECT
        week_no,
        occupancy,
        LAG(occupancy) OVER (
            ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED)
        ) AS prev_occupancy
    FROM weekly_occupancy
)
SELECT
    week_no,
    ROUND(occupancy, 2) AS current_occupancy,
    ROUND(prev_occupancy, 2) AS previous_occupancy,
    CONCAT(
        ROUND(
            (occupancy - prev_occupancy) * 100.0 / prev_occupancy,
            2
        ),
        '%'
    ) AS `Occupancy WoW change %`
FROM occupancy_wow
ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED);

--   -----------------  23	ADR WoW change % ------------------
WITH weekly_revenue AS (
    SELECT
        d.week_no,
        SUM(f.revenue_realized) AS revenue
    FROM fact_bookings f
    JOIN dim_date d
        ON f.check_in_date = d.date
    GROUP BY d.week_no
),
weekly_successful AS (
    SELECT
        d.week_no,
        SUM(a.successful_bookings) AS successful_bookings
    FROM fact_aggregated_bookings a
    JOIN dim_date d
        ON a.check_in_date = d.date
    GROUP BY d.week_no
),
weekly_adr AS (
    SELECT
        r.week_no,
        r.revenue / s.successful_bookings AS ADR
    FROM weekly_revenue r
    JOIN weekly_successful s
        ON r.week_no = s.week_no
),
adr_wow AS (
    SELECT
        week_no,
        ADR,
        LAG(ADR) OVER (
            ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED)
        ) AS Prev_ADR
    FROM weekly_adr
)
SELECT
    week_no,
    ROUND(ADR, 0) AS ADR,
    ROUND(Prev_ADR, 0) AS Prev_ADR,
    CONCAT(
        ROUND(
            (ADR - Prev_ADR) * 100.0 / Prev_ADR,
            2
        ),
        '%'
    ) AS `ADR WoW change %`
FROM adr_wow
ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED);

--   -----------------  24	Revpar WoW change % ------------------
DESCRIBE dim_date;
SELECT `week_no`
FROM dim_date
LIMIT 5;

WITH weekly_data AS (
    SELECT
        d.`week_no` AS week_no,
        SUM(f.revenue_generated) AS revenue,
        (
            SELECT SUM(a.capacity)
            FROM fact_aggregated_bookings a
            JOIN dim_date dd
                ON a.check_in_date = dd.date
            WHERE dd.`week_no` = d.`week_no`
        ) AS capacity
    FROM fact_bookings f
    JOIN dim_date d
        ON f.check_in_date = d.date
    GROUP BY d.`week_no`
),
revpar_data AS (
    SELECT
        week_no,
        revenue / capacity AS revpar
    FROM weekly_data
),
wow_data AS (
    SELECT
        week_no,
        revpar,
        LAG(revpar) OVER (
            ORDER BY CAST(SUBSTRING(week_no, 3) AS UNSIGNED)
        ) AS prev_revpar
    FROM revpar_data
)
SELECT
    week_no AS `Row Labels`,
    ROUND(revpar, 0) AS RevPAR,
    ROUND(prev_revpar, 0) AS Prev_RevPAR,
    CONCAT(
        ROUND(
            (revpar - prev_revpar) * 100.0 / prev_revpar,
            1
        ),
        '%'
    ) AS `RevPAR WOW %`
FROM wow_data
ORDER BY CAST(SUBSTRING(week_no, 3) AS UNSIGNED);

--   -----------------  25	DSRN WoW change % ------------------
WITH weekly_dsrn AS (
    SELECT 
        d.week_no, 
        ROUND(
            SUM(a.capacity) / COUNT(DISTINCT a.check_in_date),
            0
        ) AS DSRN
    FROM fact_aggregated_bookings a 
    JOIN dim_date d 
        ON a.check_in_date = d.date 
    GROUP BY d.week_no 
), 
dsrn_wow AS ( 
    SELECT 
        week_no, 
        DSRN, 
        LAG(DSRN) OVER ( 
            ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED)
        ) AS Prev_DSRN 
    FROM weekly_dsrn 
) 
SELECT 
    week_no, 
    DSRN,
    Prev_DSRN, 
    CONCAT( 
        ROUND(
            (DSRN - Prev_DSRN) * 100.0 / Prev_DSRN,
            2
        ),
        '%'
    ) AS `DSRN WoW change %`
FROM dsrn_wow 
ORDER BY CAST(REPLACE(week_no, 'W ', '') AS UNSIGNED);

