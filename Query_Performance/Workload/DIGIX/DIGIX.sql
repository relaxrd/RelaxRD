-- =========================================================
-- DIGIX workload for query performance evaluation
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
-- Retrieve all exposure records of one user from the large table,
-- e.g., when analyzing the recommendation logs associated with
-- a specific user identifier.
SELECT
    `id`,
    `uid`,
    `adv_id`,
    `age`,
    `app_score`,
    `pt_d`
FROM r0
WHERE `uid` = 1406853;


-- Q2:
-- Business scenario:
-- Inspect one lookup-style entry in the large table,
-- e.g., when checking the device price associated with a given
-- device code.
SELECT DISTINCT
    `device_name`,
    `device_price`
FROM r0
WHERE `device_name` = 56;


-- Q3:
-- Business scenario:
-- Filter records on a regular attribute in the large table,
-- e.g., when profiling users in a certain encoded age range.
SELECT
    `id`,
    `uid`,
    `adv_id`,
    `age`,
    `app_score`,
    `net_type`
FROM r0
WHERE `age` BETWEEN 4 AND 7;



-- =========================================================
-- Queries corresponding to join-based lookups in decomposed schema
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve user-side profile information together with device metadata,
-- i.e., the single-table counterpart of a lightweight one-hop lookup.
SELECT
    `uid`,
    `device_name`,
    `device_price`,
    `city`,
    `gender`
FROM r0
WHERE `uid` = 1406853;


-- Q5:
-- Business scenario:
-- Reconstruct exposure records filtered by indexed-like attributes,
-- e.g., when inspecting one user's interactions with a specific ad.
SELECT
    `id`,
    `uid`,
    `city`,
    `adv_id`,
    `task_id`,
    `tags`,
    `app_score`
FROM r0
WHERE `uid` = 1406853
  AND `adv_id` = 4407;


-- Q6:
-- Business scenario:
-- Reconstruct records with partially selective predicates,
-- e.g., when analyzing one indexed-like advertisement together with
-- a non-index age filter.
SELECT
    `id`,
    `uid`,
    `city`,
    `city_rank`,
    `adv_id`,
    `task_id`,
    `age`,
    `app_score`
FROM r0
WHERE `adv_id` = 4407
  AND `age` BETWEEN 4 AND 7;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize exposure volume by advertisement id,
-- e.g., to understand how traffic is distributed across ads.
SELECT
    `adv_id`,
    COUNT(*) AS cnt
FROM r0
GROUP BY `adv_id`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average app score by city rank,
-- e.g., to compare engagement quality across different city tiers.
SELECT
    `city_rank`,
    AVG(`app_score`) AS avg_app_score
FROM r0
GROUP BY `city_rank`
ORDER BY avg_app_score DESC;


-- Q9:
-- Business scenario:
-- Identify the top device codes with the highest average app score
-- under one indexed advertisement group.
SELECT
    `device_name`,
    AVG(`app_score`) AS avg_app_score
FROM r0
WHERE `adv_id` = 4407
GROUP BY `device_name`
ORDER BY avg_app_score DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived exposure record,
-- e.g., when a fresh ad impression is appended to the system.
INSERT INTO r0 (
    `id`,
    `uid`,
    `task_id`,
    `adv_id`,
    `creat_type_cd`,
    `adv_prim_id`,
    `dev_id`,
    `inter_type_cd`,
    `slot_id`,
    `spread_app_id`,
    `tags`,
    `app_first_class`,
    `app_second_class`,
    `age`,
    `city`,
    `device_name`,
    `device_size`,
    `career`,
    `gender`,
    `net_type`,
    `residence`,
    `his_app_size`,
    `his_on_shelf_time`,
    `app_score`,
    `emui_dev`,
    `list_time`,
    `device_price`,
    `up_life_duration`,
    `up_membership_grade`,
    `membership_life_duration`,
    `consume_purchase`,
    `communication_onlinerate`,
    `communication_avgonline_30d`,
    `indu_name`,
    `pt_d`
) VALUES (
    900000001,
    1406853,
    5029,
    4407,
    7,
    178,
    17,
    5,
    16,
    70,
    39,
    4,
    17,
    7,
    294,
    56,
    141,
    9,
    2,
    2,
    34,
    2,
    3,
    88,
    13,
    180,
    4999,
    1000,
    18,
    -1,
    -1,
    '0^1^2^3^4^5^6^7^8^9^10^11^12^13^14^15^16^17^18^19^20^21^22^23',
    13,
    36,
    9
);


-- Q11:
-- Business scenario:
-- Update one specific exposure record,
-- e.g., when the system corrects the app score of a given record id.
UPDATE r0
SET
    `app_score` = 92
WHERE `id` = 900000001;


-- Q12:
-- Business scenario:
-- Delete one specific exposure record,
-- e.g., when an invalid or duplicated profile must be removed.
DELETE FROM r0
WHERE `id` = 900000001;