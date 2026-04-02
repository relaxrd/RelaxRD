-- =========================================================
-- NCVOTER workload for query performance evaluation
-- Decomposed schema:
--   r1(age, age_group)
--   r2(county_desc, county_id)
--   r3(ethnic_code, ethnic_desc)
--   r4(load_dt, snapshot_dt)
--   r5(reason_cd, status_cd, voter_status_reason_desc)
--   r6(sex, sex_code)
--   r7(status_cd, voter_status_desc)
--   r8(county_desc, state_cd, zip_code)
--   r9(main table)
--   r0(residual table for union)
--
-- Join graph:
--   r9 joins with r1/r3/r4/r5/r6/r8
--   r5 joins with r7
--   r8 joins with r2
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve voter records under one indexed age value from the main table,
-- e.g., when slicing the voter population by a specific age.
    SELECT
        `ncid`,
        `voter_reg_num`,
        `age`,
        `party_cd`,
        `sex`,
        `zip_code`
    FROM r9
    WHERE `age` = 35
    UNION ALL
    SELECT
        `ncid`,
        `voter_reg_num`,
        `age`,
        `party_cd`,
        `sex`,
        `zip_code`
    FROM r0
    WHERE `age` = 35;


-- Q2:
-- Business scenario:
-- Inspect one lookup entry in a small dictionary table,
-- e.g., when checking the mapping between a sex label and its code.

    SELECT DISTINCT `sex`, `sex_code`
    FROM r6
    WHERE `sex` = 'M'
    UNION ALL
    SELECT `sex`, `sex_code`
    FROM r0
    WHERE `sex` = 'M';


-- Q3:
-- Business scenario:
-- Filter voter records on a non-index regular attribute in the main table,
-- e.g., when profiling voters of one party affiliation.

    SELECT
        `ncid`,
        `party_cd`,
        `race_desc`,
        `registr_dt`,
        `zip_code`
    FROM r9
    WHERE `party_cd` = 'DEM'
    UNION ALL
    SELECT
        `ncid`,
        `party_cd`,
        `race_desc`,
        `registr_dt`,
        `zip_code`
    FROM r0
    WHERE `party_cd` = 'DEM';



-- =========================================================
-- Join Queries
-- =========================================================

-- Q4:
-- Business scenario:
-- Join two decomposed small tables to decode voter status metadata,
-- e.g., when translating a reason code into its status code and
-- the corresponding human-readable voter status.

    SELECT
        r5.`reason_cd`,
        r5.`status_cd`,
        r5.`voter_status_reason_desc`,
        r7.`voter_status_desc`
    FROM r5
    JOIN r7 USING (`status_cd`)
    WHERE `reason_cd` = 'A'
    UNION ALL
    SELECT
        `reason_cd`,
        `status_cd`,
        `voter_status_reason_desc`,
        `voter_status_desc`
    FROM r0
    WHERE `reason_cd` = 'A';


-- Q5:
-- Business scenario:
-- Reconstruct a voter profile with several dimension tables,
-- while filtering on indexed foreign-key attributes,
-- e.g., when inspecting 35-year-old voters in one ZIP area.
    SELECT
        r9.`ncid`,
        r9.`voter_reg_num`,
        r9.`age`,
        r1.`age_group`,
        r9.`sex`,
        r6.`sex_code`,
        r9.`zip_code`,
        r8.`county_desc`,
        r2.`county_id`
    FROM r9
    JOIN r1 USING (`age`)
    JOIN r6 USING (`sex`)
    JOIN r8 USING (`zip_code`)
    JOIN r2 USING (`county_desc`)
    WHERE `age` = 35
  AND `zip_code` = '27513'
    UNION ALL
    SELECT
        `ncid`,
        `voter_reg_num`,
        `age`,
        `age_group`,
        `sex`,
        `sex_code`,
        `zip_code`,
        `county_desc`,
        `county_id`
    FROM r0
    WHERE `age` = 35
  AND `zip_code` = '27513';



-- Q6:
-- Business scenario:
-- Reconstruct voter status information with partially indexed predicates,
-- e.g., when analyzing one indexed age group but also restricting
-- to one non-index party affiliation.
    SELECT
        r9.`ncid`,
        r9.`age`,
        r1.`age_group`,
        r9.`party_cd`,
        r9.`reason_cd`,
        r5.`status_cd`,
        r5.`voter_status_reason_desc`,
        r7.`voter_status_desc`
    FROM r9
    JOIN r1 USING (`age`)
    JOIN r5 USING (`reason_cd`)
    JOIN r7 USING (`status_cd`)
    WHERE `age` = 35
  AND `party_cd` = 'DEM'
    UNION ALL
    SELECT
        `ncid`,
        `age`,
        `age_group`,
        `party_cd`,
        `reason_cd`,
        `status_cd`,
        `voter_status_reason_desc`,
        `voter_status_desc`
    FROM r0
    WHERE `age` = 35
  AND `party_cd` = 'DEM';




-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize voter population by indexed age value,
-- e.g., to understand how voters are distributed across age slices.
WITH r_original AS (
    SELECT `age`
    FROM r9
    UNION ALL
    SELECT `age`
    FROM r0
)
SELECT
    `age`,
    COUNT(*) AS cnt
FROM r_original
GROUP BY `age`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average voter age by party affiliation,
-- e.g., to compare demographic tendencies across parties.
WITH r_original AS (
    SELECT
        `party_cd`,
        `age`
    FROM r9
    UNION ALL
    SELECT
        `party_cd`,
        `age`
    FROM r0
)
SELECT
    `party_cd`,
    AVG(`age`) AS avg_age
FROM r_original
GROUP BY `party_cd`
ORDER BY avg_age DESC;


-- Q9:
-- Business scenario:
-- Identify the top counties with the largest number of voters
-- under one active status group, e.g., for geographic voter-status analysis.
WITH r_original AS (
    SELECT
        r8.`county_desc`,
        r5.`status_cd`
    FROM r9
    JOIN r8 USING (`zip_code`)
    JOIN r5 USING (`reason_cd`)
    WHERE `status_cd` = 'A'
    UNION ALL
    SELECT
        `county_desc`,
        `status_cd`
    FROM r0
    WHERE `status_cd` = 'A'
)
SELECT
    `county_desc`,
    COUNT(*) AS cnt
FROM r_original
GROUP BY `county_desc`
ORDER BY cnt DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived voter record,
-- e.g., when a fresh registration profile is appended to the system.
INSERT INTO r0 (
    `snapshot_dt`,
    `county_id`,
    `county_desc`,
    `voter_reg_num`,
    `ncid`,
    `status_cd`,
    `voter_status_desc`,
    `reason_cd`,
    `voter_status_reason_desc`,
    `state_cd`,
    `zip_code`,
    `race_desc`,
    `ethnic_code`,
    `ethnic_desc`,
    `party_cd`,
    `sex_code`,
    `sex`,
    `age`,
    `registr_dt`,
    `cancellation_dt`,
    `load_dt`,
    `age_group`
) VALUES (
    '2025-03-01',
    '183',
    'WAKE',
    'VRN9990001',
    'NCID9990001',
    'A',
    'ACTIVE',
    'A',
    'ACTIVE STATUS',
    'NC',
    '27513',
    'WHITE',
    'NL',
    'NOT LATIN',
    'DEM',
    'M',
    'M',
    35,
    '2025-03-01',
    NULL,
    '2025-03-01',
    '35-44'
);


-- Q11:
-- Business scenario:
-- Update one specific voter record,
-- e.g., when the system corrects party and status-related information
-- for one voter identified by NCID.

CREATE TEMPORARY TABLE tmp_q11 AS
SELECT
    `snapshot_dt`,
    `county_id`,
    `county_desc`,
    `voter_reg_num`,
    `ncid`,
    `status_cd`,
    `voter_status_desc`,
    `reason_cd`,
    `voter_status_reason_desc`,
    `state_cd`,
    `zip_code`,
    `race_desc`,
    `ethnic_code`,
    `ethnic_desc`,
    `party_cd`,
    `sex_code`,
    `sex`,
    `age`,
    `registr_dt`,
    `cancellation_dt`,
    `load_dt`,
    `age_group`
FROM (
    SELECT
        r4.`snapshot_dt`,
        r2.`county_id`,
        r8.`county_desc`,
        r9.`voter_reg_num`,
        r9.`ncid`,
        r5.`status_cd`,
        r7.`voter_status_desc`,
        r9.`reason_cd`,
        r5.`voter_status_reason_desc`,
        r8.`state_cd`,
        r9.`zip_code`,
        r9.`race_desc`,
        r9.`ethnic_code`,
        r3.`ethnic_desc`,
        r9.`party_cd`,
        r6.`sex_code`,
        r9.`sex`,
        r9.`age`,
        r9.`registr_dt`,
        r9.`cancellation_dt`,
        r9.`load_dt`,
        r1.`age_group`
    FROM r9
    JOIN r1 USING (`age`)
    JOIN r3 USING (`ethnic_code`)
    JOIN r4 USING (`load_dt`)
    JOIN r5 USING (`reason_cd`)
    JOIN r6 USING (`sex`)
    JOIN r8 USING (`zip_code`)
    JOIN r2 USING (`county_desc`)
    JOIN r7 ON r5.`status_cd` = r7.`status_cd`
    WHERE r9.`ncid` = 'NCID9990001'

    UNION ALL

    SELECT
        `snapshot_dt`,
        `county_id`,
        `county_desc`,
        `voter_reg_num`,
        `ncid`,
        `status_cd`,
        `voter_status_desc`,
        `reason_cd`,
        `voter_status_reason_desc`,
        `state_cd`,
        `zip_code`,
        `race_desc`,
        `ethnic_code`,
        `ethnic_desc`,
        `party_cd`,
        `sex_code`,
        `sex`,
        `age`,
        `registr_dt`,
        `cancellation_dt`,
        `load_dt`,
        `age_group`
    FROM r0
    WHERE `ncid` = 'NCID9990001'
) AS src;

DELETE FROM r9
WHERE `ncid` = 'NCID9990001';

DELETE FROM r0
WHERE `ncid` = 'NCID9990001';

INSERT INTO r0 (
    `snapshot_dt`,
    `county_id`,
    `county_desc`,
    `voter_reg_num`,
    `ncid`,
    `status_cd`,
    `voter_status_desc`,
    `reason_cd`,
    `voter_status_reason_desc`,
    `state_cd`,
    `zip_code`,
    `race_desc`,
    `ethnic_code`,
    `ethnic_desc`,
    `party_cd`,
    `sex_code`,
    `sex`,
    `age`,
    `registr_dt`,
    `cancellation_dt`,
    `load_dt`,
    `age_group`
)
SELECT
    `snapshot_dt`,
    `county_id`,
    `county_desc`,
    `voter_reg_num`,
    `ncid`,
    'A' AS `status_cd`,
    'ACTIVE' AS `voter_status_desc`,
    `reason_cd`,
    `voter_status_reason_desc`,
    `state_cd`,
    `zip_code`,
    `race_desc`,
    `ethnic_code`,
    `ethnic_desc`,
    'REP' AS `party_cd`,
    `sex_code`,
    `sex`,
    `age`,
    `registr_dt`,
    `cancellation_dt`,
    `load_dt`,
    `age_group`
FROM tmp_q11;

DROP TEMPORARY TABLE tmp_q11;


-- Q12:
-- Business scenario:
-- Delete one specific voter record,
-- e.g., when an invalid, duplicated, or revoked registration
-- must be removed from storage.
DELETE FROM r9
WHERE `ncid` = 'NCID9990001';
DELETE FROM r0
WHERE `ncid` = 'NCID9990001';