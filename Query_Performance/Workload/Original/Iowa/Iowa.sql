-- =========================================================
-- IOWA workload for query performance evaluation
-- Single large table version: r0
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1
SELECT
    `Invoice/Item Number`,
    `Date`,
    `Store Number`,
    `Category Name`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r0
WHERE `Category Name` = 'VODKA 80 PROOF';


-- Q2
SELECT
    `Category`,
    `Category Name`
FROM r0
WHERE `Category Name` = 'VODKA 80 PROOF';


-- Q3
SELECT
    `Invoice/Item Number`,
    `Store Number`,
    `Store Name`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r0
WHERE `Sale (Dollars)` BETWEEN 100 AND 300;



-- =========================================================
-- Lookup / Join-equivalent Queries
-- =========================================================

-- Q4
SELECT
    `Invoice/Item Number`,
    `County`,
    `County Number`,
    `Store Number`,
    `Store Name`
FROM r0
WHERE `County` = 'POLK';


-- Q5
SELECT
    `Invoice/Item Number`,
    `Date`,
    `Category Name`,
    `Category`,
    `Vendor Name`,
    `Vendor Number`,
    `Sale (Dollars)`
FROM r0
WHERE `Category Name` = 'VODKA 80 PROOF'
  AND `Vendor Name` = 'DIAGEO AMERICAS';


-- Q6
SELECT
    `Invoice/Item Number`,
    `Category Name`,
    `Category`,
    `Item Number`,
    `Item Description`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r0
WHERE `Category Name` = 'VODKA 80 PROOF'
  AND `Sale (Dollars)` BETWEEN 100 AND 300;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7
SELECT
    `Category Name`,
    COUNT(*) AS cnt
FROM r0
GROUP BY `Category Name`
ORDER BY cnt DESC;


-- Q8
SELECT
    `County`,
    AVG(`Sale (Dollars)`) AS avg_sale
FROM r0
GROUP BY `County`
ORDER BY avg_sale DESC;


-- Q9
SELECT
    `Vendor Name`,
    SUM(`Sale (Dollars)`) AS total_sale
FROM r0
WHERE `Category Name` = 'VODKA 80 PROOF'
GROUP BY `Vendor Name`
ORDER BY total_sale DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10
INSERT INTO r0 (
    `Invoice/Item Number`,
    `Date`,
    `Store Number`,
    `Store Name`,
    `Address`,
    `City`,
    `Zip Code`,
    `Store Location`,
    `County Number`,
    `County`,
    `Category`,
    `Category Name`,
    `Vendor Number`,
    `Vendor Name`,
    `Item Number`,
    `Item Description`,
    `Pack`,
    `Bottle Volume (ml)`,
    `State Bottle Cost`,
    `State Bottle Retail`,
    `Bottles Sold`,
    `Sale (Dollars)`,
    `Volume Sold (Liters)`,
    `Volume Sold (Gallons)`
) VALUES (
    'INV-999999',
    '2025-03-01',
    9999,
    'TEST STORE',
    '123 TEST ST',
    'DES MOINES',
    '50309',
    '(41.5868, -93.6250)',
    77,
    'POLK',
    1031100,
    'VODKA 80 PROOF',
    260,
    'DIAGEO AMERICAS',
    100001,
    'TEST VODKA',
    12,
    750,
    10.00,
    15.00,
    24,
    360.00,
    68.112,
    18.0
);


-- Q11
UPDATE r0
SET
    `Sale (Dollars)` = 400.00
WHERE `Invoice/Item Number` = 'INV-999999';


-- Q12
DELETE FROM r0
WHERE `Invoice/Item Number` = 'INV-999999';