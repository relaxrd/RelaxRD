-- =========================================================
-- SCHOOL workload for query performance evaluation
-- Single large table version: r0
--
-- This workload follows the same logic as the decomposed version:
--   (1) no-join point/range queries,
--   (2) queries corresponding to join-based lookups in the decomposed schema,
--   (3) analytical queries,
--   (4) lightweight write operations.
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve school-year records under one indexed-like grouping attribute,
-- e.g., when analyzing all records in one overall performance band.
SELECT
    `year`,
    `school`,
    `total_candidates`,
    `pct_div_7`,
    `male_pct_div3`
FROM r0
WHERE `pct_div_7` = 90;


-- Q2:
-- Business scenario:
-- Inspect one lookup-style entry associated with one FK pair,
-- e.g., when checking the percentage mapping for a specific
-- (`pct_div_7`, `male_pct_div3`) combination.
SELECT DISTINCT
    `pct_div_7`,
    `male_pct_div3`,
    `female_pct_div7`,
    `male_pct_div7`
FROM r0
WHERE `pct_div_7` = 90
  AND `male_pct_div3` = 10;


-- Q3:
-- Business scenario:
-- Filter records on a regular non-key attribute,
-- e.g., when profiling schools with a medium-size candidate population.
SELECT
    `year`,
    `school`,
    `total_candidates`,
    `male_candidates`,
    `female_candidates`
FROM r0
WHERE `total_candidates` BETWEEN 400 AND 600;



-- =========================================================
-- Queries corresponding to join-based lookups in decomposed schema
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve school-year records together with district information,
-- i.e., the lightest lookup that corresponds to the decomposed join.
SELECT
    `year`,
    `school`,
    `district`,
    `total_candidates`
FROM r0
WHERE `school` = 'SCHOOL_001';


-- Q5:
-- Business scenario:
-- Reconstruct records filtered by indexed-like attributes,
-- e.g., when inspecting one school under one performance band.
SELECT
    `year`,
    `school`,
    `district`,
    `total_candidates`,
    `pct_div_7`,
    `male_pct_div3`
FROM r0
WHERE `school` = 'SCHOOL_001'
  AND `pct_div_7` = 90;


-- Q6:
-- Business scenario:
-- Reconstruct records with partially selective predicates,
-- e.g., when analyzing one indexed-like performance band together with
-- a non-key candidate-count filter.
SELECT
    `year`,
    `school`,
    `district`,
    `total_candidates`,
    `pct_div_7`,
    `male_pct_div3`,
    `female_pct_div7`,
    `male_pct_div7`
FROM r0
WHERE `pct_div_7` = 90
  AND `total_candidates` BETWEEN 400 AND 600;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize record volume by `pct_div_7`,
-- e.g., to understand how schools are distributed across performance bands.
SELECT
    `pct_div_7`,
    COUNT(*) AS cnt
FROM r0
GROUP BY `pct_div_7`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average total candidates by district,
-- e.g., to compare school size across districts.
SELECT
    `district`,
    AVG(`total_candidates`) AS avg_total_candidates
FROM r0
GROUP BY `district`
ORDER BY avg_total_candidates DESC;


-- Q9:
-- Business scenario:
-- Identify the top schools with the largest number of candidates
-- under one `pct_div_7` group.
SELECT
    `school`,
    MAX(`total_candidates`) AS max_total_candidates
FROM r0
WHERE `pct_div_7` = 90
GROUP BY `school`
ORDER BY max_total_candidates DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived school-year record,
-- e.g., when a new yearly school profile is appended to the system.
INSERT INTO r0 (
    `year`,
    `district`,
    `school`,
    `total_candidates`,
    `pct_div_1`,
    `pct_div_2`,
    `pct_div_3`,
    `pct_div_4`,
    `pct_div_7`,
    `pct_div_9`,
    `pct_x`,
    `female_candidates`,
    `female_pct_div1`,
    `female_pct_div2`,
    `female_pct_div3`,
    `female_pct_div4`,
    `female_pct_div7`,
    `female_pct_div9`,
    `female_pct_x`,
    `male_candidates`,
    `male_pct_div1`,
    `male_pct_div2`,
    `male_pct_div3`,
    `male_pct_div4`,
    `male_pct_div7`,
    `male_pct_div9`,
    `male_pct_x`
) VALUES (
    2099,
    'DISTRICT_999',
    'SCHOOL_999',
    500,
    5,
    8,
    10,
    12,
    90,
    15,
    50,
    240,
    4,
    7,
    9,
    10,
    88,
    14,
    52,
    260,
    6,
    9,
    10,
    14,
    92,
    16,
    48
);


-- Q11:
-- Business scenario:
-- Update one specific school-year record,
-- e.g., when the system corrects candidate statistics for a given school-year key.
UPDATE r0
SET
    `total_candidates` = 520
WHERE `year` = 2099
  AND `school` = 'SCHOOL_999';


-- Q12:
-- Business scenario:
-- Delete one specific school-year record,
-- e.g., when an invalid or duplicated profile must be removed.
DELETE FROM r0
WHERE `year` = 2099
  AND `school` = 'SCHOOL_999';