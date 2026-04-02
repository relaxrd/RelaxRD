-- =========================================================
-- FRAUD workload for query performance evaluation
-- Single large table version: fraud_transactions
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve transaction records under one indexed-like foreign-key attribute,
-- e.g., when inspecting all transactions issued by one specific card.
SELECT
    `trans_num`,
    `trans_date_trans_time`,
    `cc_num`,
    `merchant`,
    `amt`,
    `unix_time`
FROM fraud_transactions
WHERE `cc_num` = '4000000000000001';


-- Q2:
-- Business scenario:
-- Inspect one lookup-style entry,
-- e.g., when checking the category associated with one merchant.
SELECT DISTINCT
    `merchant`,
    `category`
FROM fraud_transactions
WHERE `merchant` = 'fraud_Rutherford-Mertz';


-- Q3:
-- Business scenario:
-- Filter transactions on a non-FK regular attribute,
-- e.g., when profiling medium-to-large transactions by amount.
SELECT
    `trans_num`,
    `trans_date_trans_time`,
    `merchant`,
    `amt`
FROM fraud_transactions
WHERE `amt` BETWEEN 100 AND 300;



-- =========================================================
-- Queries corresponding to join-based lookups in decomposed schema
-- =========================================================

-- Q4:
-- Business scenario:
-- Decode customer metadata,
-- e.g., when translating a first name into gender information.
SELECT DISTINCT
    `cc_num`,
    `first`,
    `gender`,
    `state`,
    `zip`
FROM fraud_transactions
WHERE `first` = 'Jennifer';


-- Q5:
-- Business scenario:
-- Reconstruct transaction records filtered by indexed-like attributes,
-- e.g., when inspecting all transactions of one card at one merchant.
SELECT
    `trans_num`,
    `trans_date_trans_time`,
    `cc_num`,
    `first`,
    `last`,
    `merchant`,
    `category`,
    `amt`
FROM fraud_transactions
WHERE `cc_num` = '4000000000000001'
  AND `merchant` = 'fraud_Rutherford-Mertz';


-- Q6:
-- Business scenario:
-- Reconstruct transaction records with partially selective predicates,
-- e.g., when analyzing transactions of one indexed-like merchant together with
-- a non-key amount filter.
SELECT
    `trans_num`,
    `merchant`,
    `category`,
    `cc_num`,
    `first`,
    `gender`,
    `amt`
FROM fraud_transactions
WHERE `merchant` = 'fraud_Rutherford-Mertz'
  AND `amt` BETWEEN 100 AND 300;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize transaction volume by merchant,
-- e.g., to understand how transactions are distributed across merchants.
SELECT
    `merchant`,
    COUNT(*) AS cnt
FROM fraud_transactions
GROUP BY `merchant`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average transaction amount by merchant category,
-- e.g., to compare transaction size across spending categories.
SELECT
    `category`,
    AVG(`amt`) AS avg_amt
FROM fraud_transactions
where amt>50
GROUP BY `category`
ORDER BY avg_amt DESC;


-- Q9:
-- Business scenario:
-- Identify the top states with the largest total suspicious exposure,
-- e.g., for geographic fraud-risk analysis.
SELECT
    `state`,
    SUM(`amt`) AS total_amt
FROM fraud_transactions
WHERE `is_fraud` = 1
GROUP BY `state`
ORDER BY total_amt DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived transaction record,
-- e.g., when a fresh card transaction is appended to the system.
INSERT INTO fraud_transactions (
    `trans_date_trans_time`,
    `cc_num`,
    `merchant`,
    `category`,
    `amt`,
    `first`,
    `last`,
    `gender`,
    `street`,
    `city`,
    `state`,
    `zip`,
    `lat`,
    `long`,
    `city_pop`,
    `job`,
    `dob`,
    `trans_num`,
    `unix_time`,
    `merch_lat`,
    `merch_long`,
    `is_fraud`
) VALUES (
    '2025-03-01 12:00:00',
    '4000000000000001',
    'fraud_Rutherford-Mertz',
    'shopping_pos',
    188.50,
    'Jennifer',
    'Smith',
    'F',
    '123 Test St',
    'Des Moines',
    'IA',
    '50309',
    41.5868,
    -93.6250,
    214133,
    'Scientist',
    '1985-05-01',
    'TXN999999001',
    1740830400,
    41.6000,
    -93.6200,
    0
);


-- Q11:
-- Business scenario:
-- Update one specific transaction record,
-- e.g., when the system corrects the transaction amount
-- or fraud label for a given transaction id.
UPDATE fraud_transactions
SET
    `amt` = 250.00,
    `is_fraud` = 1
WHERE `trans_num` = 'TXN999999001';


-- Q12:
-- Business scenario:
-- Delete one specific transaction record,
-- e.g., when an invalid or duplicated transaction must be removed.
DELETE FROM fraud_transactions
WHERE `trans_num` = 'TXN999999001';