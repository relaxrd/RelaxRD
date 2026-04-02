-- =========================================================
-- SCHOOL workload for query performance evaluation
-- Decomposed schema:
--   r1(`female_pct_div7`, `male_pct_div3`, `male_pct_div7`, `pct_div_7`)
--   r2(`district`, `school`)
--   r3(main table)
--   r0(residual table for union)
--
-- Join graph:
--   r3 joins with r1 using (`pct_div_7`, `male_pct_div3`)
--   r3 joins with r2 using (`school`)
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve school-year records under one indexed FK attribute from the main table,
-- e.g., when analyzing all records in one overall performance band.
SELECT
    `year`,
    `school`,
    `total_candidates`,
    `pct_div_7`,
    `male_pct_div3`
FROM r3
WHERE `pct_div_7` = 90

UNION ALL

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
-- Inspect one lookup entry in the small percentage dictionary table,
-- e.g., when checking the mapping associated with one FK pair.
SELECT DISTINCT
    `pct_div_7`,
    `male_pct_div3`,
    `female_pct_div7`,
    `male_pct_div7`
FROM (
    SELECT
        `pct_div_7`,
        `male_pct_div3`,
        `female_pct_div7`,
        `male_pct_div7`
    FROM r1
    WHERE `pct_div_7` = 90
      AND `male_pct_div3` = 10

    UNION ALL

    SELECT
        `pct_div_7`,
        `male_pct_div3`,
        `female_pct_div7`,
        `male_pct_div7`
    FROM r0
    WHERE `pct_div_7` = 90
      AND `male_pct_div3` = 10
) AS t;


-- Q3:
-- Business scenario:
-- Filter records on a non-FK regular attribute in the main table,
-- e.g., when profiling schools with a medium-size candidate population.
SELECT
    `year`,
    `school`,
    `total_candidates`,
    `male_candidates`,
    `female_candidates`
FROM r3
WHERE `total_candidates` BETWEEN 400 AND 600

UNION ALL

SELECT
    `year`,
    `school`,
    `total_candidates`,
    `male_candidates`,
    `female_candidates`
FROM r0
WHERE `total_candidates` BETWEEN 400 AND 600;



-- =========================================================
-- Join Queries
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve school-year records together with district information,
-- i.e., the lightest one-join lookup in this decomposed schema.
SELECT
    r3.`year`,
    r3.`school`,
    r2.`district`,
    r3.`total_candidates`
FROM r3
JOIN r2 USING (`school`)
WHERE r3.`school` = 'SCHOOL_001'

UNION ALL

SELECT
    `year`,
    `school`,
    `district`,
    `total_candidates`
FROM r0
WHERE `school` = 'SCHOOL_001';


-- Q5:
-- Business scenario:
-- Reconstruct records with indexed predicates on FK attributes,
-- e.g., when inspecting one school under one performance band.
SELECT
    r3.`year`,
    r3.`school`,
    r2.`district`,
    r3.`total_candidates`,
    r3.`pct_div_7`,
    r3.`male_pct_div3`
FROM r3
JOIN r2 USING (`school`)
WHERE r3.`school` = 'SCHOOL_001'
  AND r3.`pct_div_7` = 90

UNION ALL

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
-- Reconstruct records with partially indexed predicates,
-- e.g., when analyzing one indexed performance band together with
-- a non-index candidate-count filter.
SELECT
    r3.`year`,
    r3.`school`,
    r2.`district`,
    r3.`total_candidates`,
    r3.`pct_div_7`,
    r3.`male_pct_div3`,
    r1.`female_pct_div7`,
    r1.`male_pct_div7`
FROM r3
JOIN r2 USING (`school`)
JOIN r1 USING (`pct_div_7`, `male_pct_div3`)
WHERE r3.`pct_div_7` = 90
  AND r3.`total_candidates` BETWEEN 400 AND 600

UNION ALL

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
-- Summarize record volume by an indexed grouping attribute,
-- e.g., to understand how schools are distributed across pct_div_7 bands.
SELECT
    `pct_div_7`,
    COUNT(*) AS cnt
FROM (
    SELECT `pct_div_7`
    FROM r3

    UNION ALL

    SELECT `pct_div_7`
    FROM r0
) AS t
GROUP BY `pct_div_7`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average total candidates by district,
-- e.g., to compare school size across districts.
SELECT
    `district`,
    AVG(`total_candidates`) AS avg_total_candidates
FROM (
    SELECT
        r2.`district`,
        r3.`total_candidates`
    FROM r3
    JOIN r2 USING (`school`)

    UNION ALL

    SELECT
        `district`,
        `total_candidates`
    FROM r0
) AS t
GROUP BY `district`
ORDER BY avg_total_candidates DESC;


-- Q9:
-- Business scenario:
-- Identify the top schools with the largest number of candidates
-- under one indexed pct_div_7 group.
SELECT
    `school`,
    MAX(`total_candidates`) AS max_total_candidates
FROM (
    SELECT
        `school`,
        `total_candidates`
    FROM r3
    WHERE `pct_div_7` = 90

    UNION ALL

    SELECT
        `school`,
        `total_candidates`
    FROM r0
    WHERE `pct_div_7` = 90
) AS t
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
CREATE TEMPORARY TABLE tmp_q11 AS
SELECT
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
FROM (
    SELECT
        r3.`year`,
        r2.`district`,
        r3.`school`,
        r3.`total_candidates`,
        r3.`pct_div_1`,
        r3.`pct_div_2`,
        r3.`pct_div_3`,
        r3.`pct_div_4`,
        r3.`pct_div_7`,
        r3.`pct_div_9`,
        r3.`pct_x`,
        r3.`female_candidates`,
        r3.`female_pct_div1`,
        r3.`female_pct_div2`,
        r3.`female_pct_div3`,
        r3.`female_pct_div4`,
        r1.`female_pct_div7`,
        r3.`female_pct_div9`,
        r3.`female_pct_x`,
        r3.`male_candidates`,
        r3.`male_pct_div1`,
        r3.`male_pct_div2`,
        r3.`male_pct_div3`,
        r3.`male_pct_div4`,
        r1.`male_pct_div7`,
        r3.`male_pct_div9`,
        r3.`male_pct_x`
    FROM r3
    JOIN r2 USING (`school`)
    JOIN r1 USING (`pct_div_7`, `male_pct_div3`)
    WHERE r3.`year` = 2099
      AND r3.`school` = 'SCHOOL_999'

    UNION ALL

    SELECT
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
    FROM r0
    WHERE `year` = 2099
      AND `school` = 'SCHOOL_999'
) AS src;

DELETE FROM r3
WHERE `year` = 2099
  AND `school` = 'SCHOOL_999';

DELETE FROM r0
WHERE `year` = 2099
  AND `school` = 'SCHOOL_999';

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
)
SELECT
    `year`,
    `district`,
    `school`,
    520 AS `total_candidates`,
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
FROM tmp_q11;

DROP TEMPORARY TABLE tmp_q11;


-- Q12:
-- Business scenario:
-- Delete one specific school-year record,
-- e.g., when an invalid or duplicated profile must be removed.
DELETE FROM r3
WHERE `year` = 2099
  AND `school` = 'SCHOOL_999';

DELETE FROM r0
WHERE `year` = 2099
  AND `school` = 'SCHOOL_999';