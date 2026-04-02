-- =========================================================
-- ADULT workload for query performance evaluation
-- Single large table version: r0
--
-- This workload follows the same logic as the decomposed version:
--   (1) no-join point/range queries,
--   (2) queries that correspond to one-join lookups in the decomposed schema,
--   (3) analytical queries,
--   (4) lightweight write operations.
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve records under one education category from the large table,
-- e.g., when analyzing individuals with a specific education background.
SELECT a1, a3, a4, a6, a15
FROM r0
WHERE a4 = 'Bachelors';


-- Q2:
-- Business scenario:
-- Inspect one education entry and its numeric education code,
-- e.g., when checking the mapping from education label to education number.
SELECT DISTINCT a4, a5
FROM r0
WHERE a4 = 'Assoc-acdm';


-- Q3:
-- Business scenario:
-- Filter records on a non-index numeric attribute,
-- e.g., when profiling people with positive capital gains.
SELECT a1, a3, a11, a13, a15
FROM r0
WHERE a11 BETWEEN 5000 AND 15000;



-- =========================================================
-- Queries corresponding to one-join lookups in decomposed schema
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve both education label and numeric code
-- for working-age individuals.
SELECT a1, a3, a4, a5, a13
FROM r0
WHERE a1 BETWEEN 30 AND 45;


-- Q5:
-- Business scenario:
-- Retrieve records filtered by an indexed education attribute,
-- e.g., to inspect high-income individuals with a Bachelor's degree.
SELECT a3, a4, a5, a7, a15
FROM r0
WHERE a4 = 'Bachelors'
  AND a15 = '>50K';


-- Q6:
-- Business scenario:
-- Retrieve records with partially selective predicates,
-- e.g., to inspect Bachelor's-degree individuals who work long hours.
SELECT a3, a4, a5, a7, a13, a15
FROM r0
WHERE a4 = 'Bachelors'
  AND a13 BETWEEN 40 AND 60;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize population distribution by education category,
-- e.g., to understand how individuals are distributed across
-- education groups.
SELECT a4, COUNT(*) AS cnt
FROM r0
GROUP BY a4
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average weekly working hours by sex,
-- e.g., to compare labor intensity between male and female groups.
SELECT a10, AVG(a13) AS avg_hours_per_week
FROM r0
GROUP BY a10
ORDER BY avg_hours_per_week DESC;


-- Q9:
-- Business scenario:
-- Identify the top occupations among high-income individuals,
-- e.g., for occupation-level income structure analysis.
SELECT a7, COUNT(*) AS cnt
FROM r0
WHERE a15 = '>50K'
GROUP BY a7
ORDER BY cnt DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived individual record,
-- e.g., when a new workforce profile is appended to the system.
-- Note:
-- a3 = 2000000 is chosen as a fresh identifier.
INSERT INTO r0 (
    a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15
) VALUES (
    41,
    'Private',
    2000000,
    'Bachelors',
    13,
    'Married-civ-spouse',
    'Prof-specialty',
    'Husband',
    'White',
    'Male',
    0,
    0,
    45,
    'United-States',
    '>50K'
);


-- Q11:
-- Business scenario:
-- Update one specific individual record,
-- e.g., when the system corrects income-related attributes
-- for a given person identified by a3.
UPDATE r0
SET
    a11 = 5000,
    a12 = 0,
    a15 = '>50K'
WHERE a3 = 205019;


-- Q12:
-- Business scenario:
-- Delete one specific individual record,
-- e.g., when an invalid, duplicated, or revoked profile must be removed.
DELETE FROM r0
WHERE a3 = 121772;