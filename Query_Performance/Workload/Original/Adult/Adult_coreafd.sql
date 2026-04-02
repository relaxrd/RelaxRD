-- =========================================================
-- ADULT workload for query performance evaluation
-- Decomposed schema:
--   r1(a4, a5)            -- small table, a4 is primary key
--   r2(all attributes except a5)  -- main table, a4 is foreign key
--   r0                    -- residual table for union
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve records under one education category from the main table,
-- e.g., when analyzing individuals with a specific education background.
SELECT `a1`, `a3`, `a4`, `a6`, `a15`
FROM r2
WHERE `a4` = 'Bachelors'
UNION ALL
SELECT `a1`, `a3`, `a4`, `a6`, `a15`
FROM r0
WHERE `a4` = 'Bachelors';


-- Q2:
-- Business scenario:
-- Inspect one education lookup entry in the small dictionary table,
-- e.g., when checking the mapping from education label to education number.
SELECT DISTINCT `a4`, `a5`
FROM (
    SELECT `a4`, `a5`
    FROM r1
    WHERE `a4` = 'Assoc-acdm'
    UNION ALL
    SELECT `a4`, `a5`
    FROM r0
    WHERE `a4` = 'Assoc-acdm'
) AS t;


-- Q3:
-- Business scenario:
-- Filter records on a non-index numeric attribute in the main table,
-- e.g., when profiling people with positive capital gains.
SELECT `a1`, `a3`, `a11`, `a13`, `a15`
FROM r2
WHERE `a11` BETWEEN 5000 AND 15000
UNION ALL
SELECT `a1`, `a3`, `a11`, `a13`, `a15`
FROM r0
WHERE `a11` BETWEEN 5000 AND 15000;



-- =========================================================
-- One-Join Queries
-- =========================================================

-- Q4:
-- Business scenario:
-- Join the main table with the education dictionary,
-- e.g., to retrieve both education label and numeric code
-- for working-age individuals.
SELECT `a1`, `a3`, `a4`, `a5`, `a13`
FROM r2
JOIN r1 USING (`a4`)
WHERE `a1` BETWEEN 30 AND 45
UNION ALL
SELECT `a1`, `a3`, `a4`, `a5`, `a13`
FROM r0
WHERE `a1` BETWEEN 30 AND 45;


-- Q5:
-- Business scenario:
-- Retrieve joined records filtered by an indexed education attribute,
-- e.g., to inspect high-income individuals with a Bachelor's degree.
SELECT `a3`, `a4`, `a5`, `a7`, `a15`
FROM r2
JOIN r1 USING (`a4`)
WHERE `a4` = 'Bachelors'
  AND `a15` = '>50K'
UNION ALL
SELECT `a3`, `a4`, `a5`, `a7`, `a15`
FROM r0
WHERE `a4` = 'Bachelors'
  AND `a15` = '>50K';


-- Q6:
-- Business scenario:
-- Retrieve joined records with partially indexed predicates,
-- e.g., to inspect Bachelor's-degree individuals who work long hours.
SELECT `a3`, `a4`, `a5`, `a7`, `a13`, `a15`
FROM r2
JOIN r1 USING (`a4`)
WHERE `a4` = 'Bachelors'
  AND `a13` BETWEEN 40 AND 60
UNION ALL
SELECT `a3`, `a4`, `a5`, `a7`, `a13`, `a15`
FROM r0
WHERE `a4` = 'Bachelors'
  AND `a13` BETWEEN 40 AND 60;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize population distribution by education category,
-- e.g., to understand how individuals are distributed across
-- indexed education groups.
SELECT `a4`, COUNT(*) AS cnt
FROM (
    SELECT `a4`
    FROM r2
    UNION ALL
    SELECT `a4`
    FROM r0
) AS t
GROUP BY `a4`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average weekly working hours by sex,
-- e.g., to compare labor intensity between male and female groups.
SELECT `a10`, AVG(`a13`) AS avg_hours_per_week
FROM (
    SELECT `a10`, `a13`
    FROM r2
    UNION ALL
    SELECT `a10`, `a13`
    FROM r0
) AS t
GROUP BY `a10`
ORDER BY avg_hours_per_week DESC;


-- Q9:
-- Business scenario:
-- Identify the top occupations among high-income individuals,
-- e.g., for occupation-level income structure analysis.
SELECT `a7`, COUNT(*) AS cnt
FROM (
    SELECT `a7`, `a15`
    FROM r2
    WHERE `a15` = '>50K'
    UNION ALL
    SELECT `a7`, `a15`
    FROM r0
    WHERE `a15` = '>50K'
) AS t
GROUP BY `a7`
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

CREATE TEMPORARY TABLE tmp_q11 AS
SELECT
    `a1`, `a2`, `a3`, `a4`, `a5`, `a6`, `a7`, `a8`, `a9`,
    `a10`, `a11`, `a12`, `a13`, `a14`, `a15`
FROM (
    SELECT
        r2.`a1`, r2.`a2`, r2.`a3`, r2.`a4`, r1.`a5`, r2.`a6`, r2.`a7`, r2.`a8`, r2.`a9`,
        r2.`a10`, r2.`a11`, r2.`a12`, r2.`a13`, r2.`a14`, r2.`a15`
    FROM r2
    JOIN r1 USING (`a4`)
    WHERE r2.`a3` = 205019

    UNION ALL

    SELECT
        `a1`, `a2`, `a3`, `a4`, `a5`, `a6`, `a7`, `a8`, `a9`,
        `a10`, `a11`, `a12`, `a13`, `a14`, `a15`
    FROM r0
    WHERE `a3` = 205019
) AS src;

DELETE FROM r2
WHERE `a3` = 205019;

DELETE FROM r0
WHERE `a3` = 205019;

INSERT INTO r0 (
    a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15
)
SELECT
    `a1`,
    `a2`,
    `a3`,
    `a4`,
    `a5`,
    `a6`,
    `a7`,
    `a8`,
    `a9`,
    `a10`,
    5000 AS `a11`,
    0 AS `a12`,
    `a13`,
    `a14`,
    '>50K' AS `a15`
FROM tmp_q11;

DROP TEMPORARY TABLE tmp_q11;


-- Q12:
-- Business scenario:
-- Delete one specific individual record,
-- e.g., when an invalid, duplicated, or revoked profile must be removed.
DELETE FROM r2
WHERE `a3` = 121772;

DELETE FROM r0
WHERE `a3` = 121772;