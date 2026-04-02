-- =========================================================
-- IOWA workload for query performance evaluation
-- Decomposed schema:
--   r1(`Category`, `Category Name`)
--   r2(`County`, `County Number`)
--   r3(`Bottle Volume (ml)`, `Item Description`, `Item Number`, `Pack`)
--   r4(`Vendor Name`, `Vendor Number`)
--   r5(`Volume Sold (Gallons)`, `Volume Sold (Liters)`)
--   r6(main table)
--   r0(residual table for union)
--
-- Join graph:
--   r6 joins with r1/r2/r3/r4/r5
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve sales records under one indexed product category from the main table,
-- e.g., when analyzing all transactions belonging to a specific liquor category.
SELECT
    `Invoice/Item Number`,
    `Date`,
    `Store Number`,
    `Category Name`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r6
WHERE `Category Name` = 'VODKA 80 PROOF'
UNION ALL
SELECT
    `Invoice/Item Number`,
    `Date`,
    `Store Number`,
    `Category Name`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r0
WHERE `Category Name` = 'VODKA 80 PROOF';


-- Q2:
-- Business scenario:
-- Inspect one lookup entry in a small dictionary table,
-- e.g., when checking the numeric category code associated with a category name.

SELECT `Category`, `Category Name`
FROM r1
WHERE `Category Name` = 'VODKA 80 PROOF'
    UNION ALL

    SELECT `Category`, `Category Name`
    FROM r0
    WHERE `Category Name` = 'VODKA 80 PROOF';


-- Q3:
-- Business scenario:
-- Filter transactions on a non-FK regular attribute in the main table,
-- e.g., when profiling medium-size sales records by transaction value.
SELECT
    `Invoice/Item Number`,
    `Store Number`,
    `Store Name`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r6
WHERE `Sale (Dollars)` BETWEEN 100 AND 300

UNION ALL

SELECT
    `Invoice/Item Number`,
    `Store Number`,
    `Store Name`,
    `Sale (Dollars)`,
    `Bottles Sold`
FROM r0
WHERE `Sale (Dollars)` BETWEEN 100 AND 300;



-- =========================================================
-- Join Queries
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve county metadata for one transaction group,
-- i.e., the lightest one-join lookup in this decomposed schema.
SELECT
    r6.`Invoice/Item Number`,
    r6.`County`,
    r2.`County Number`,
    r6.`Store Number`,
    r6.`Store Name`
FROM r6
JOIN r2 USING (`County`)
WHERE r6.`County` = 'POLK'

UNION ALL

SELECT
    `Invoice/Item Number`,
    `County`,
    `County Number`,
    `Store Number`,
    `Store Name`
FROM r0
WHERE `County` = 'POLK';


-- Q5:
-- Business scenario:
-- Reconstruct sales records filtered by indexed FK attributes,
-- e.g., when inspecting one vendor within one category.
SELECT
    r6.`Invoice/Item Number`,
    r6.`Date`,
    r6.`Category Name`,
    r1.`Category`,
    r6.`Vendor Name`,
    r4.`Vendor Number`,
    r6.`Sale (Dollars)`
FROM r6
JOIN r1 USING (`Category Name`)
JOIN r4 USING (`Vendor Name`)
WHERE r6.`Category Name` = 'VODKA 80 PROOF'
  AND r6.`Vendor Name` = 'DIAGEO AMERICAS'

UNION ALL

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


-- Q6:
-- Business scenario:
-- Reconstruct sales records with partially indexed predicates,
-- e.g., when analyzing one indexed product category together with
-- a non-index sales-amount filter.
SELECT
    r6.`Invoice/Item Number`,
    r6.`Category Name`,
    r1.`Category`,
    r6.`Item Number`,
    r3.`Item Description`,
    r6.`Sale (Dollars)`,
    r6.`Bottles Sold`
FROM r6
JOIN r1 USING (`Category Name`)
JOIN r3 USING (`Item Number`)
WHERE r6.`Category Name` = 'VODKA 80 PROOF'
  AND r6.`Sale (Dollars)` BETWEEN 100 AND 300

UNION ALL

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

-- Q7:
-- Business scenario:
-- Summarize transaction volume by an indexed grouping attribute,
-- e.g., to understand how sales are distributed across category names.
SELECT
    `Category Name`,
    COUNT(*) AS cnt
FROM (
    SELECT `Category Name`
    FROM r6

    UNION ALL

    SELECT `Category Name`
    FROM r0
) AS t
GROUP BY `Category Name`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average sales value by county,
-- e.g., to compare transaction size across counties.
SELECT
    `County`,
    AVG(`Sale (Dollars)`) AS avg_sale
FROM (
    SELECT
        r6.`County`,
        r6.`Sale (Dollars)`
    FROM r6
    JOIN r2 USING (`County`)

    UNION ALL

    SELECT
        `County`,
        `Sale (Dollars)`
    FROM r0
) AS t
GROUP BY `County`
ORDER BY avg_sale DESC;


-- Q9:
-- Business scenario:
-- Identify the top vendors with the largest total sales
-- under one indexed category group.
SELECT
    `Vendor Name`,
    SUM(`Sale (Dollars)`) AS total_sale
FROM (
    SELECT
        `Vendor Name`,
        `Sale (Dollars)`
    FROM r6
    WHERE `Category Name` = 'VODKA 80 PROOF'

    UNION ALL

    SELECT
        `Vendor Name`,
        `Sale (Dollars)`
    FROM r0
    WHERE `Category Name` = 'VODKA 80 PROOF'
) AS t
GROUP BY `Vendor Name`
ORDER BY total_sale DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived sales record,
-- e.g., when a new liquor transaction is appended to the system.
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


-- Q11:
-- Business scenario:
-- Update one specific transaction record,
-- e.g., when the system corrects the sales amount for a given invoice item.
CREATE TEMPORARY TABLE tmp_q11 AS
SELECT
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
FROM (
    SELECT
        r6.`Invoice/Item Number`,
        r6.`Date`,
        r6.`Store Number`,
        r6.`Store Name`,
        r6.`Address`,
        r6.`City`,
        r6.`Zip Code`,
        r6.`Store Location`,
        r2.`County Number`,
        r6.`County`,
        r1.`Category`,
        r6.`Category Name`,
        r4.`Vendor Number`,
        r6.`Vendor Name`,
        r6.`Item Number`,
        r3.`Item Description`,
        r3.`Pack`,
        r3.`Bottle Volume (ml)`,
        r6.`State Bottle Cost`,
        r6.`State Bottle Retail`,
        r6.`Bottles Sold`,
        r6.`Sale (Dollars)`,
        r5.`Volume Sold (Liters)`,
        r6.`Volume Sold (Gallons)`
    FROM r6
    JOIN r1 USING (`Category Name`)
    JOIN r2 USING (`County`)
    JOIN r3 USING (`Item Number`)
    JOIN r4 USING (`Vendor Name`)
    JOIN r5 USING (`Volume Sold (Gallons)`)
    WHERE r6.`Invoice/Item Number` = 'INV-999999'

    UNION ALL

    SELECT
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
    FROM r0
    WHERE `Invoice/Item Number` = 'INV-999999'
) AS src;

DELETE FROM r6
WHERE `Invoice/Item Number` = 'INV-999999';

DELETE FROM r0
WHERE `Invoice/Item Number` = 'INV-999999';

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
)
SELECT
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
    400.00 AS `Sale (Dollars)`,
    `Volume Sold (Liters)`,
    `Volume Sold (Gallons)`
FROM tmp_q11;

DROP TEMPORARY TABLE tmp_q11;


-- Q12:
-- Business scenario:
-- Delete one specific sales record,
-- e.g., when an invalid or duplicated invoice item must be removed.
DELETE FROM r6
WHERE `Invoice/Item Number` = 'INV-999999';

DELETE FROM r0
WHERE `Invoice/Item Number` = 'INV-999999';