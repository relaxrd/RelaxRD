-- =========================================================
-- NCVOTER workload for query performance evaluation
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
-- Retrieve voter records under one indexed age value,
-- e.g., when slicing the voter population by a specific age.
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
-- Inspect one lookup entry between a sex label and its code,
-- e.g., when checking the mapping between sex and sex_code.
SELECT DISTINCT
    `sex`,
    `sex_code`
FROM r0
WHERE `sex` = 'M';


-- Q3:
-- Business scenario:
-- Filter voter records on a non-index regular attribute,
-- e.g., when profiling voters of one party affiliation.
SELECT
    `ncid`,
    `party_cd`,
    `race_desc`,
    `registr_dt`,
    `zip_code`
FROM r0
WHERE `party_cd` = 'DEM';



-- =========================================================
-- Queries corresponding to join-based lookups in decomposed schema
-- =========================================================

-- Q4:
-- Business scenario:
-- Decode voter status metadata,
-- e.g., when translating a reason code into its status code and
-- corresponding voter-status description.
SELECT
    `reason_cd`,
    `status_cd`,
    `voter_status_reason_desc`,
    `voter_status_desc`
FROM r0
WHERE `reason_cd` = 'A';


-- Q5:
-- Business scenario:
-- Reconstruct a voter profile that includes age grouping,
-- sex code, ZIP/county information, and county identifier,
-- while filtering on indexed attributes.
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
SELECT
    `age`,
    COUNT(*) AS cnt
FROM r0
GROUP BY `age`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average voter age by party affiliation,
-- e.g., to compare demographic tendencies across parties.
SELECT
    `party_cd`,
    AVG(`age`) AS avg_age
FROM r0
GROUP BY `party_cd`
ORDER BY avg_age DESC;


-- Q9:
-- Business scenario:
-- Identify the top counties with the largest number of voters
-- under one active status group, e.g., for geographic voter-status analysis.
SELECT
    `county_desc`,
    COUNT(*) AS cnt
FROM r0
WHERE `status_cd` = 'A'
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
UPDATE r0
SET
    `status_cd` = 'A',
    `voter_status_desc` = 'ACTIVE',
    `party_cd` = 'REP'
WHERE `ncid` = 'NCID9990001';


-- Q12:
-- Business scenario:
-- Delete one specific voter record,
-- e.g., when an invalid, duplicated, or revoked registration
-- must be removed from storage.
DELETE FROM r0
WHERE `ncid` = 'NCID9990001';