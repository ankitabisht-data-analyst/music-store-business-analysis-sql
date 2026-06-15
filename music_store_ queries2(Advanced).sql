-- ================================================================
--  MUSIC STORE DATA ANALYSIS — 15 MEDIUM TO ADVANCED QUESTIONS
--  Each block contains: Business Question → Strategy Note → Query
-- ================================================================


-- ── Q1 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Which sales support agent generated the most revenue?
--   Return agent name, number of customers handled, and total
--   revenue they brought in.
--
-- STRATEGY:
--   employee → customer (support_rep_id) → invoice (total).
--   Single GROUP BY with SUM; idx_customer_support speeds the join.
-- ────────────────────────────────────────────────────────────────
SELECT
    CONCAT(e.first_name, ' ', e.last_name)  AS agent_name,
    e.title,
    COUNT(DISTINCT c.customer_id)           AS customers_handled,
    ROUND(SUM(i.total), 2)                  AS total_revenue
FROM employee  e
JOIN customer  c ON c.support_rep_id = e.employee_id
JOIN invoice   i ON i.customer_id    = c.customer_id
WHERE e.title LIKE '%Sales Support Agent%'
GROUP BY e.employee_id, e.first_name, e.last_name, e.title
ORDER BY total_revenue DESC;


-- ── Q2 ──────────────────────────────────────────────────────────
-- QUESTION:
--   What is the month-over-month revenue trend across all years?
--   Return year, month, revenue, and the revenue from the
--   previous month to spot growth or decline.
--
-- STRATEGY:
--   DATE functions on invoice_date + LAG() window function for
--   the previous-month comparison. No self-join needed.
-- ────────────────────────────────────────────────────────────────
WITH monthly_revenue AS (
    SELECT
        YEAR(invoice_date)                  AS yr,
        MONTH(invoice_date)                 AS mo,
        DATE_FORMAT(invoice_date, '%Y-%m')  AS yr_mo,
        ROUND(SUM(total), 2)                AS revenue
    FROM invoice
    GROUP BY yr, mo, yr_mo
)
SELECT
    yr_mo,
    revenue,
    LAG(revenue) OVER (ORDER BY yr, mo)     AS prev_month_revenue,
    ROUND(
        revenue - LAG(revenue) OVER (ORDER BY yr, mo)
    , 2)                                    AS mom_change
FROM monthly_revenue
ORDER BY yr, mo;


-- ── Q3 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Which album generated the highest total revenue?
--   Return album title, artist name, track count, and total revenue.
--
-- STRATEGY:
--   album → track → invoice_line chain with SUM.
--   Covering indexes on track(album_id) and il(track_id) make
--   this a fast range scan rather than a full table scan.
-- ────────────────────────────────────────────────────────────────
SELECT
    al.title                                AS album_title,
    ar.name                                 AS artist_name,
    COUNT(DISTINCT t.track_id)              AS track_count,
    ROUND(SUM(il.unit_price * il.quantity), 2) AS album_revenue
FROM album        al
JOIN artist       ar ON ar.artist_id  = al.artist_id
JOIN track        t  ON t.album_id    = al.album_id
JOIN invoice_line il ON il.track_id   = t.track_id
GROUP BY al.album_id, al.title, ar.artist_id, ar.name
ORDER BY album_revenue DESC
LIMIT 10;


-- ── Q4 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Find customers who have NEVER made a purchase.
--   (Useful for re-engagement campaigns.)
--
-- STRATEGY:
--   LEFT JOIN + NULL check is faster than NOT IN / NOT EXISTS
--   on large datasets because it avoids subquery re-execution.
-- ────────────────────────────────────────────────────────────────
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.email,
    c.country
FROM customer c
LEFT JOIN invoice i ON i.customer_id = c.customer_id
WHERE i.invoice_id IS NULL
ORDER BY c.country, customer_name;


-- ── Q5 ──────────────────────────────────────────────────────────
-- QUESTION:
--   What is the average order value (AOV) per country?
--   Rank countries from highest to lowest AOV.
--
-- STRATEGY:
--   Simple AVG(total) grouped by billing_country.
--   DENSE_RANK() added so ties share the same position.
-- ────────────────────────────────────────────────────────────────
SELECT
    billing_country                         AS country,
    COUNT(*)                                AS total_invoices,
    ROUND(AVG(total), 2)                    AS avg_order_value,
    DENSE_RANK() OVER (
        ORDER BY AVG(total) DESC
    )                                       AS aov_rank
FROM invoice
GROUP BY billing_country
ORDER BY avg_order_value DESC;


-- ── Q6 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Which genres are declining — i.e., sold more in the first
--   half of the dataset's date range than the second half?
--
-- STRATEGY:
--   Use MIN/MAX of invoice_date to compute the midpoint dynamically,
--   then pivot into first-half vs second-half buckets using
--   conditional aggregation (SUM + CASE). No temp table needed.
-- ────────────────────────────────────────────────────────────────
WITH date_bounds AS (
    SELECT
        MIN(invoice_date)                                               AS min_date,
        DATE_ADD(
            MIN(invoice_date),
            INTERVAL DATEDIFF(MAX(invoice_date), MIN(invoice_date)) / 2 DAY
        )                                                               AS mid_date
    FROM invoice
),
genre_half_sales AS (
    SELECT
        g.name                                                          AS genre,
        SUM(CASE WHEN i.invoice_date < db.mid_date
                 THEN il.quantity ELSE 0 END)                           AS first_half_qty,
        SUM(CASE WHEN i.invoice_date >= db.mid_date
                 THEN il.quantity ELSE 0 END)                           AS second_half_qty
    FROM invoice       i
    JOIN date_bounds   db  ON 1 = 1
    JOIN invoice_line  il  ON il.invoice_id = i.invoice_id
    JOIN track         t   ON t.track_id    = il.track_id
    JOIN genre         g   ON g.genre_id    = t.genre_id
    GROUP BY g.genre_id, g.name
)
SELECT
    genre,
    first_half_qty,
    second_half_qty,
    (second_half_qty - first_half_qty)      AS change_in_qty,
    CASE
        WHEN second_half_qty < first_half_qty THEN 'DECLINING'
        WHEN second_half_qty > first_half_qty THEN 'GROWING'
        ELSE 'STABLE'
    END                                     AS trend
FROM genre_half_sales
ORDER BY change_in_qty ASC;


-- ── Q7 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Which tracks have NEVER been purchased?
--   Return track name, album, artist, and genre.
--   (Useful to identify dead inventory.)
--
-- STRATEGY:
--   LEFT JOIN track → invoice_line, filter where il is NULL.
--   Much faster than NOT IN (subquery) because NOT IN can't use
--   indexes when NULLs are possible.
-- ────────────────────────────────────────────────────────────────
SELECT
    t.track_id,
    t.name                                  AS track_name,
    al.title                                AS album_title,
    ar.name                                 AS artist_name,
    g.name                                  AS genre
FROM track        t
JOIN album        al ON al.album_id   = t.album_id
JOIN artist       ar ON ar.artist_id  = al.artist_id
JOIN genre        g  ON g.genre_id    = t.genre_id
LEFT JOIN invoice_line il ON il.track_id = t.track_id
WHERE il.invoice_line_id IS NULL
ORDER BY ar.name, al.title, t.name;


-- ── Q8 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Which playlists contain the most Rock tracks and what
--   percentage of each playlist is Rock?
--
-- STRATEGY:
--   Two conditional COUNTs (total vs rock) in one pass using
--   SUM(CASE) — avoids a double scan of playlist_track.
-- ────────────────────────────────────────────────────────────────
SELECT
    p.name                                                              AS playlist_name,
    COUNT(pt.track_id)                                                  AS total_tracks,
    SUM(CASE WHEN g.name = 'Rock' THEN 1 ELSE 0 END)                   AS rock_tracks,
    ROUND(
        SUM(CASE WHEN g.name = 'Rock' THEN 1 ELSE 0 END)
        / COUNT(pt.track_id) * 100
    , 1)                                                                AS rock_pct
FROM playlist      p
JOIN playlist_track pt ON pt.playlist_id = p.playlist_id
JOIN track          t  ON t.track_id     = pt.track_id
JOIN genre          g  ON g.genre_id     = t.genre_id
GROUP BY p.playlist_id, p.name
HAVING rock_tracks > 0
ORDER BY rock_tracks DESC;


-- ── Q9 ──────────────────────────────────────────────────────────
-- QUESTION:
--   Identify the top 5% of customers by spend using percentile
--   ranking. Return their name, country, total spend, and
--   their percentile rank.
--
-- STRATEGY:
--   PERCENT_RANK() window function — native in MySQL 8+.
--   No self-join or subquery needed to calculate percentile.
-- ────────────────────────────────────────────────────────────────
WITH customer_spend AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
        c.country,
        ROUND(SUM(i.total), 2)                  AS total_spent
    FROM customer c
    JOIN invoice  i ON i.customer_id = c.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
),
ranked AS (
    SELECT *,
        ROUND(PERCENT_RANK() OVER (ORDER BY total_spent) * 100, 1)
            AS percentile_rank
    FROM customer_spend
)
SELECT
    customer_name,
    country,
    total_spent,
    percentile_rank
FROM ranked
WHERE percentile_rank >= 95
ORDER BY total_spent DESC;


-- ── Q10 ─────────────────────────────────────────────────────────
-- QUESTION:
--   For each artist, show the running cumulative revenue over time
--   (first sale to latest). Only show the top 5 artists by
--   total revenue.
--
-- STRATEGY:
--   CTE pre-filters to top-5 artists so the window function
--   runs only on a small subset. SUM() OVER with ORDER BY
--   invoice_date gives the running total per artist.
-- ────────────────────────────────────────────────────────────────
WITH artist_revenue AS (
    SELECT
        ar.artist_id,
        ar.name                                                     AS artist_name,
        DATE(i.invoice_date)                                        AS sale_date,
        ROUND(SUM(il.unit_price * il.quantity), 2)                  AS daily_revenue
    FROM artist       ar
    JOIN album        al ON al.artist_id  = ar.artist_id
    JOIN track        t  ON t.album_id    = al.album_id
    JOIN invoice_line il ON il.track_id   = t.track_id
    JOIN invoice      i  ON i.invoice_id  = il.invoice_id
    GROUP BY ar.artist_id, ar.name, sale_date
),
top5_artists AS (
    SELECT artist_id
    FROM artist_revenue
    GROUP BY artist_id
    ORDER BY SUM(daily_revenue) DESC
    LIMIT 5
)
SELECT
    ar.artist_name,
    ar.sale_date,
    ar.daily_revenue,
    ROUND(
        SUM(ar.daily_revenue) OVER (
            PARTITION BY ar.artist_id
            ORDER BY ar.sale_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
    , 2)                                                            AS cumulative_revenue
FROM artist_revenue ar
WHERE ar.artist_id IN (SELECT artist_id FROM top5_artists)
ORDER BY ar.artist_name, ar.sale_date;


-- ── Q11 ─────────────────────────────────────────────────────────
-- QUESTION:
--   Which customers have purchased from more than 3 different
--   genres? (Cross-genre buyers — valuable for personalization.)
--
-- STRATEGY:
--   COUNT(DISTINCT genre_id) per customer after joining the
--   invoice → track → genre chain. HAVING filter limits results.
-- ────────────────────────────────────────────────────────────────
SELECT
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    c.email,
    c.country,
    COUNT(DISTINCT t.genre_id)              AS genres_purchased
FROM customer    c
JOIN invoice     i   ON i.customer_id  = c.customer_id
JOIN invoice_line il  ON il.invoice_id  = i.invoice_id
JOIN track       t   ON t.track_id     = il.track_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.country
HAVING genres_purchased > 3
ORDER BY genres_purchased DESC, customer_name;


-- ── Q12 ─────────────────────────────────────────────────────────
-- QUESTION:
--   Employee hierarchy — show each employee, their manager,
--   and their manager's manager (two levels up) using a
--   self-join. Useful for org-chart and reporting chain analysis.
--
-- STRATEGY:
--   Two LEFT JOINs on the same employee table aliased differently.
--   LEFT JOIN ensures top-level employees (no manager) still appear.
-- ────────────────────────────────────────────────────────────────
SELECT
    CONCAT(e.first_name, ' ', e.last_name)          AS employee,
    e.title                                          AS employee_title,
    e.levels                                         AS level,
    CONCAT(m.first_name, ' ', m.last_name)           AS direct_manager,
    m.title                                          AS manager_title,
    CONCAT(gm.first_name, ' ', gm.last_name)         AS grand_manager,
    gm.title                                         AS grand_manager_title
FROM employee  e
LEFT JOIN employee m  ON m.employee_id  = e.reports_to
LEFT JOIN employee gm ON gm.employee_id = m.reports_to
ORDER BY e.levels DESC, e.last_name;


-- ── Q13 ─────────────────────────────────────────────────────────
-- QUESTION:
--   What is the average number of tracks per invoice?
--   Also show the distribution: how many invoices had 1 track,
--   2 tracks, 3 tracks, etc.? (Order size analysis.)
--
-- STRATEGY:
--   First CTE counts tracks per invoice. Second CTE groups by
--   that count to build the distribution. Clean and one-pass.
-- ────────────────────────────────────────────────────────────────
WITH invoice_track_count AS (
    SELECT
        invoice_id,
        SUM(quantity)                       AS tracks_ordered
    FROM invoice_line
    GROUP BY invoice_id
),
distribution AS (
    SELECT
        tracks_ordered,
        COUNT(*)                            AS number_of_invoices
    FROM invoice_track_count
    GROUP BY tracks_ordered
)
SELECT
    tracks_ordered,
    number_of_invoices,
    ROUND(
        number_of_invoices / SUM(number_of_invoices) OVER () * 100
    , 1)                                    AS pct_of_orders
FROM distribution
ORDER BY tracks_ordered;


-- ── Q14 ─────────────────────────────────────────────────────────
-- QUESTION:
--   Which media type generates the most revenue and has the
--   highest number of unique tracks sold?
--   (Helps decide which format to prioritize/promote.)
--
-- STRATEGY:
--   media_type → track → invoice_line chain.
--   COUNT(DISTINCT) for unique tracks vs SUM for revenue.
-- ────────────────────────────────────────────────────────────────
SELECT
    mt.name                                             AS media_type,
    COUNT(DISTINCT t.track_id)                          AS unique_tracks_sold,
    SUM(il.quantity)                                    AS total_units_sold,
    ROUND(SUM(il.unit_price * il.quantity), 2)          AS total_revenue,
    ROUND(
        SUM(il.unit_price * il.quantity)
        / SUM(SUM(il.unit_price * il.quantity)) OVER () * 100
    , 1)                                                AS revenue_share_pct
FROM media_type   mt
JOIN track        t  ON t.media_type_id = mt.media_type_id
JOIN invoice_line il ON il.track_id     = t.track_id
GROUP BY mt.media_type_id, mt.name
ORDER BY total_revenue DESC;


-- ── Q15 ─────────────────────────────────────────────────────────
-- QUESTION:
--   Find customers who made purchases in EVERY year that the
--   store has sales records. These are the most loyal, consistent
--   long-term customers.
--
-- STRATEGY:
--   COUNT(DISTINCT year) per customer must equal the total number
--   of distinct years in the invoice table. Subquery computes the
--   year count once; HAVING enforces the equality.
-- ────────────────────────────────────────────────────────────────
WITH years_in_data AS (
    SELECT COUNT(DISTINCT YEAR(invoice_date)) AS total_years
    FROM invoice
),
customer_active_years AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
        c.email,
        c.country,
        COUNT(DISTINCT YEAR(i.invoice_date))     AS years_active,
        ROUND(SUM(i.total), 2)                   AS lifetime_spend
    FROM customer  c
    JOIN invoice   i ON i.customer_id = c.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.country
)
SELECT
    cay.customer_name,
    cay.email,
    cay.country,
    cay.years_active,
    cay.lifetime_spend
FROM customer_active_years cay
JOIN years_in_data         yid ON cay.years_active = yid.total_years
ORDER BY cay.lifetime_spend DESC;


-- ================================================================
-- END OF FILE
-- ================================================================
