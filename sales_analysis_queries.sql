USE gdb023;

-- 1. Markets in which “Atliq Exclusive” operates in APAC
CREATE OR REPLACE VIEW vw_markets_apac_atliq AS
SELECT
    market
FROM dim_customer
WHERE region = 'APAC'
  AND customer = 'Atliq Exclusive';

-- 2. % change in unique products 2021 vs 2020
CREATE OR REPLACE VIEW vw_unique_products_change AS
WITH product_counts AS (
    SELECT 
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_products
    FROM fact_gross_price
    WHERE fiscal_year IN (2020, 2021)
    GROUP BY fiscal_year
)
SELECT 
    pc2020.unique_products AS unique_products_2020,
    pc2021.unique_products AS unique_products_2021,
    ROUND(
      (pc2021.unique_products - pc2020.unique_products) * 100.0
        / NULLIF(pc2020.unique_products, 0),
      2
    ) AS percentage_chg
FROM 
    (SELECT unique_products FROM product_counts WHERE fiscal_year = 2020) AS pc2020,
    (SELECT unique_products FROM product_counts WHERE fiscal_year = 2021) AS pc2021;

-- 3. Unique product counts per segment, descending
CREATE OR REPLACE VIEW vw_product_count_by_segment AS
SELECT 
    segment,
    COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4. Segment with most increase in unique products 2021 vs 2020
CREATE OR REPLACE VIEW vw_segment_product_growth AS
WITH joined_table AS (
    SELECT
        dp.segment,
        fgp.product_code,
        fgp.fiscal_year
    FROM dim_product dp
    LEFT JOIN fact_gross_price fgp
      ON dp.product_code = fgp.product_code
)
SELECT 
    segment,
    COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS product_count_2020,
    COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS product_count_2021,
    COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END)
      - COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END)
      AS difference
FROM joined_table
GROUP BY segment
ORDER BY difference DESC;

-- 5. Products with highest and lowest manufacturing costs
CREATE OR REPLACE VIEW vw_extreme_manufacturing_costs AS
WITH manufacturing_table AS (
    SELECT 
        fmc.product_code,
        dp.product,
        fmc.manufacturing_cost
    FROM fact_manufacturing_cost fmc
    LEFT JOIN dim_product dp
      ON fmc.product_code = dp.product_code
)
SELECT *
FROM manufacturing_table
WHERE manufacturing_cost IN (
    SELECT MAX(manufacturing_cost) FROM manufacturing_table
    UNION
    SELECT MIN(manufacturing_cost) FROM manufacturing_table
);

-- 6. Top 5 customers by avg pre-invoice discount % in 2021 in India
CREATE OR REPLACE VIEW vw_top5_discount_india_2021 AS
WITH customer_table AS (
    SELECT
        dc.customer_code,
        dc.customer,
        AVG(fpd.pre_invoice_discount_pct) AS average_discount_percentage
    FROM dim_customer dc
    LEFT JOIN fact_pre_invoice_deductions fpd
      ON dc.customer_code = fpd.customer_code
    WHERE fpd.fiscal_year = 2021
      AND dc.market = 'India'
    GROUP BY dc.customer_code, dc.customer
)
SELECT
    customer_code,
    customer,
    average_discount_percentage
FROM customer_table
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- 7. Gross sales amount for “Atliq Exclusive” by month
CREATE OR REPLACE VIEW vw_monthly_gross_sales_atliq AS
SELECT
    YEAR(fsm.date)  AS Year,
    MONTH(fsm.date) AS Month,
    SUM(fsm.sold_quantity) AS Gross_sales_Amount
FROM fact_sales_monthly fsm
LEFT JOIN dim_customer dc
  ON fsm.customer_code = dc.customer_code
WHERE dc.customer = 'Atliq Exclusive'
GROUP BY Year, Month
ORDER BY Year, Month;

-- 8. Quarter of 2020 with maximum total sold quantity
CREATE OR REPLACE VIEW vw_quarterly_sales_2020 AS
SELECT
    QUARTER(fsm.date)      AS Quarter,
    SUM(fsm.sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly fsm
WHERE fsm.fiscal_year = 2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

-- 9. Channel contribution to gross sales in 2021
CREATE OR REPLACE VIEW vw_channel_contribution_2021 AS
SELECT
    dc.channel                   AS channel,
    SUM(fsm.sold_quantity)       AS gross_sales_mln,
    ROUND(
      SUM(fsm.sold_quantity) * 100.0
      / NULLIF((SELECT SUM(sold_quantity)
                FROM fact_sales_monthly
                WHERE fiscal_year = 2021),0),
      2
    )                            AS percentage
FROM fact_sales_monthly fsm
LEFT JOIN dim_customer dc
  ON fsm.customer_code = dc.customer_code
WHERE fsm.fiscal_year = 2021
GROUP BY dc.channel
ORDER BY percentage DESC;

-- 10. Top 3 products in each division by sold_quantity in 2021
CREATE OR REPLACE VIEW vw_top3_products_by_division_2021 AS
WITH ranked_products AS (
    SELECT
        dp.division,
        dp.product_code,
        dp.product,
        SUM(fsm.sold_quantity) AS total_sold_quantity,
        ROW_NUMBER() OVER (
          PARTITION BY dp.division
          ORDER BY SUM(fsm.sold_quantity) DESC
        ) AS rank_order
    FROM fact_sales_monthly fsm
    LEFT JOIN dim_product dp
      ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dp.division, dp.product_code, dp.product
)
SELECT
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM ranked_products
WHERE rank_order <= 3
ORDER BY division, rank_order;
