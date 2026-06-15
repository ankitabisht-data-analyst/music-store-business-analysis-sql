
--  MUSIC STORE DATA ANALYSIS — OPTIMIZED MySQL QUERIES
--  Schema: Chinook Music Store

-- SECTION 0  — RECOMMENDED INDEXES

-- employee
ALTER TABLE employee ADD INDEX idx_employee_title (title);

-- invoice
ALTER TABLE invoice ADD INDEX idx_invoice_customer   (customer_id);
ALTER TABLE invoice ADD INDEX idx_invoice_country    (billing_country);
ALTER TABLE invoice ADD INDEX idx_invoice_city       (billing_city);
ALTER TABLE invoice ADD INDEX idx_invoice_total      (total);

-- invoice_line
ALTER TABLE invoice_line ADD INDEX idx_il_invoice  (invoice_id);
ALTER TABLE invoice_line ADD INDEX idx_il_track    (track_id);

-- track
ALTER TABLE track ADD INDEX idx_track_album       (album_id);
ALTER TABLE track ADD INDEX idx_track_genre       (genre_id);
ALTER TABLE track ADD INDEX idx_track_ms          (milliseconds);

-- album
ALTER TABLE album ADD INDEX idx_album_artist (artist_id);

-- customer
ALTER TABLE customer ADD INDEX idx_customer_support (support_rep_id);
ALTER TABLE customer ADD INDEX idx_customer_country (country);

-- playlist_track
ALTER TABLE playlist_track ADD INDEX idx_pt_track    (track_id);
ALTER TABLE playlist_track ADD INDEX idx_pt_playlist (playlist_id);


-- SECTION 1 — EASY QUESTIONS


-- ── Q1.1 ─────────────────────────────────────────────────────
-- Who is the senior-most employee based on job title?
-- Strategy: ORDER BY the "levels" column DESC (L6 > L4 …) 

SELECT
    employee_id,
    first_name,
    last_name,
    title,
    levels
FROM employee
ORDER BY levels DESC
LIMIT 1;


-- ── Q1.2 ─────────────────────────────────────────────────────
-- Which countries have the most Invoices?

SELECT billing_country  AS country,
    COUNT(*) AS invoice_count
FROM invoice
GROUP BY billing_country
ORDER BY invoice_count DESC;


-- ── Q1.3 ─────────────────────────────────────────────────────
-- What are the top 3 values of total invoice?

SELECT DISTINCT total
FROM invoice
ORDER BY total DESC
LIMIT 3;


-- ── Q1.4 ─────────────────────────────────────────────────────
-- Which city has the best customers (highest sum of totals)?
-- Return city name + total revenue — use for Music Festival.

SELECT
    billing_city   AS city,
    ROUND(SUM(total), 2) AS invoice_sum
FROM invoice
GROUP BY billing_city
ORDER BY invoice_sum DESC
LIMIT 1;


-- ── Q1.5 ─────────────────────────────────────────────────────
-- Who is the best customer? (highest total spend)

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    ROUND(SUM(i.total), 2) AS total_spent
FROM customer  c
JOIN invoice   i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 1;



-- SECTION 2 — MODERATE QUESTIONS


-- ── Q2.1 ─────────────────────────────────────────────────────
-- Email, first name, last name & Genre of all ROCK listeners.
-- Ordered alphabetically by email.

SELECT DISTINCT
    c.email,
    c.first_name,
    c.last_name,
    g.name   AS genre
FROM customer    c
JOIN invoice   i   ON i.customer_id  = c.customer_id
JOIN invoice_line il ON il.invoice_id  = i.invoice_id
JOIN track  t   ON t.track_id   = il.track_id
JOIN genre  g   ON g.genre_id  = t.genre_id
WHERE g.name = 'Rock'
ORDER BY c.email;


-- ── Q2.2 ─────────────────────────────────────────────────────
-- Top 10 rock artists by number of rock tracks written.

SELECT
    ar. name  AS artist_name,
    COUNT(t.track_id) AS rock_track_count
FROM artist  ar
JOIN album   al ON al.artist_id  = ar.artist_id
JOIN track   t  ON t.album_id    = al.album_id
JOIN genre   g  ON g.genre_id   = t.genre_id
WHERE g.name = 'Rock'
GROUP BY ar.artist_id, ar.name
ORDER BY rock_track_count DESC
LIMIT 10;


-- ── Q2.3 ─────────────────────────────────────────────────────
-- Track names longer than the average song length.
-- Return Name + Milliseconds, longest first.

SELECT
    name,
    milliseconds
FROM track
WHERE milliseconds > (SELECT AVG(milliseconds) FROM track)
ORDER BY milliseconds DESC;


-- SECTION 3 — ADVANCED QUESTIONS


-- ── Q3.1 ─────────────────────────────────────────────────────
-- Amount spent by each customer ON EACH ARTIST.
-- Return: customer_name, artist_name, total_spent

WITH best_selling_artist AS (
       SELECT
        ar.artist_id,
        ar. name  AS artist_name,
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM artist  ar
    JOIN album  al ON al.artist_id  = ar.artist_id
    JOIN track   t  ON t.album_id    = al.album_id
    JOIN invoice_line il ON il.track_id   = t.track_id
    GROUP BY ar.artist_id, ar.name)
    
SELECT
    CONCAT(c.first_name, ' ', c.last_name)  AS customer_name,
    bsa.artist_name,
    ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent
FROM customer  c
JOIN invoice  i   ON i.customer_id   = c.customer_id
JOIN invoice_line   il  ON il.invoice_id   = i.invoice_id
JOIN track  t   ON t.track_id      = il.track_id
JOIN album   al  ON al.album_id     = t.album_id
JOIN best_selling_artist bsa ON bsa.artist_id = al.artist_id
GROUP BY
    c.customer_id,
    customer_name,
    bsa.artist_id,
    bsa.artist_name
ORDER BY total_spent DESC;


-- ── Q3.2 ─────────────────────────────────────────────────────
-- Most popular genre per country (by purchase quantity).
-- For ties, return ALL tied genres for that country.

WITH country_genre_purchases AS (
    SELECT
        i.billing_country  AS country,
        g.name    AS genre,
        COUNT(il.quantity)   AS purchase_count
    FROM invoice   i
    JOIN invoice_line  il ON il.invoice_id = i.invoice_id
    JOIN track   t  ON t.track_id    = il.track_id
    JOIN genre    g  ON g.genre_id    = t.genre_id
    GROUP BY i.billing_country, g.genre_id, g.name),
ranked AS (SELECT
        country,
        genre,
        purchase_count,
        RANK() OVER (
            PARTITION BY country
            ORDER BY purchase_count DESC ) AS rnk
    FROM country_genre_purchases)
SELECT
    country,
    genre,
    purchase_count
FROM ranked
WHERE rnk = 1
ORDER BY country, genre;


-- ── Q3.3 ─────────────────────────────────────────────────────
-- Customer who spent the most per country.
-- For ties, return ALL customers with that top amount.

WITH customer_country_spend AS (
    SELECT
        i.billing_country AS country,
        CONCAT(c.first_name, ' ', c.last_name)   AS customer_name, c.customer_id,
        ROUND(SUM(i.total), 2)   AS total_spent
    FROM customer  c
    JOIN invoice  i ON i.customer_id = c.customer_id
    GROUP BY
        i.billing_country,
        c.customer_id,
        c.first_name,
        c.last_name),
ranked AS (
    SELECT
        country,
        customer_name,
        total_spent,
        RANK() OVER (
            PARTITION BY country
            ORDER BY total_spent DESC ) AS rnk
    FROM customer_country_spend)
SELECT country,
    customer_name,
    total_spent
FROM ranked
WHERE rnk = 1
ORDER BY country, customer_name;

