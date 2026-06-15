# 🎵 Music Store Business Analysis & SQL Optimization

## 📌 Project Overview

This project analyzes the Chinook Music Store database using SQL to answer real business questions related to sales performance, customer behavior, product popularity, and revenue generation.

The objective was not only to write SQL queries, but to approach the database from a business analyst's perspective by transforming transactional data into actionable insights and optimizing query performance through indexing and efficient query design.


## 🎯 Project Goals

* Analyze customer purchasing behavior
* Identify revenue-driving customers, genres, and artists
* Evaluate sales performance across countries and cities
* Discover product and genre trends
* Apply advanced SQL techniques to solve business problems
* Improve query performance using indexing and optimization strategies


## 🗄️ Database Schema

The project uses the Chinook Database, a digital music store database containing:

* Customers
* Employees
* Invoices
* Invoice Lines
* Artists
* Albums
* Tracks
* Genres
* Media Types
* Playlists


## 📊 Business Questions Solved

### Easy Level

1. Senior-most employee based on job hierarchy
2. Countries generating the highest invoice volume
3. Top invoice values
4. Best-performing city by revenue
5. Highest-spending customer

### Intermediate Level

6. Rock music listeners and customer segmentation
7. Top artists producing Rock music
8. Tracks longer than average song duration

### Advanced Level

9. Customer spending by artist
10. Most popular genre in each country
11. Highest-spending customer per country



## 💡 Key Business Insights

* Prague generated the highest total revenue among all cities.
* Rock is the dominant genre across most countries in the dataset.
* A small group of customers contributes a significant portion of total revenue.
* Led Zeppelin, U2, and Deep Purple have the largest Rock catalogues.
* Rock music contributes the largest share of overall sales revenue.
* Customer spending patterns vary significantly across countries.
* Sales support agents contribute differently to customer revenue generation.



## 🛠 SQL Techniques Used

### Core SQL

* SELECT
* WHERE
* GROUP BY
* HAVING
* ORDER BY
* LIMIT

### Intermediate SQL

* Multi-table JOINs
* Aggregate Functions
* DISTINCT
* Scalar Subqueries
* Correlated Subqueries

### Advanced SQL

* Common Table Expressions (CTEs)
* Window Functions

  * RANK()
  * DENSE_RANK()
  * LAG()
  * PERCENT_RANK()
* Self Joins
* Conditional Aggregation
* Anti Joins
* Date Functions
* String Functions



## ⚡ (Query Optimization)

Performance optimization was implemented through indexing and efficient query design.

### Indexes Created

#### Invoice

```sql
ALTER TABLE invoice ADD INDEX idx_invoice_customer (customer_id);
ALTER TABLE invoice ADD INDEX idx_invoice_country (billing_country);
ALTER TABLE invoice ADD INDEX idx_invoice_city (billing_city);
ALTER TABLE invoice ADD INDEX idx_invoice_total (total);
```

#### Invoice Line

sql
ALTER TABLE invoice_line ADD INDEX idx_il_invoice (invoice_id);
ALTER TABLE invoice_line ADD INDEX idx_il_track (track_id);


#### Track

sql
ALTER TABLE track ADD INDEX idx_track_album (album_id);
ALTER TABLE track ADD INDEX idx_track_genre (genre_id);
ALTER TABLE track ADD INDEX idx_track_ms (milliseconds);


#### Album

sql
ALTER TABLE album ADD INDEX idx_album_artist (artist_id);


#### Customer
sql
ALTER TABLE customer ADD INDEX idx_customer_support (support_rep_id);
ALTER TABLE customer ADD INDEX idx_customer_country (country);


#### Playlist Track

sql
ALTER TABLE playlist_track ADD INDEX idx_pt_track (track_id);
ALTER TABLE playlist_track ADD INDEX idx_pt_playlist (playlist_id);

### Optimization Concepts Applied

* Foreign-key indexing
* Early aggregation
* Reduced join cardinality
* Selective column projection
* Efficient grouping strategies
* Proper use of window functions for ranking and tie handling

## 📂 Repository Structure

music-store-business-analysis-sql/
│
├── README.md
├── schema.png
├── music_store_analysis.sql
├── music_store_advanced_15.sql


## 🚀 Skills Demonstrated

* SQL Data Analysis
* Relational Database Design
* Business Intelligence
* Query Optimization
* Database Indexing
* Analytical Problem Solving
* Revenue and Customer Analytics
* Data-Driven Decision Making


## 🛠 Tools Used

* MySQL 8+
* MySQL Workbench
* Git
* GitHub
* Chinook Database

## 👨‍💻 Author

Ankit Bisht

Aspiring Data Analyst focused on SQL, Business Analytics, and Data-Driven Decision Making.
