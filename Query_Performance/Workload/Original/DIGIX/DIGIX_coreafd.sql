-- =========================================================
-- DIGIX workload for query performance evaluation
-- Decomposed schema:
--   r1(`career`, `city`, `consume_purchase`, `device_name`, `device_size`,
--      `emui_dev`, `gender`, `uid`, `up_life_duration`, `up_membership_grade`)
--   r2(`device_name`, `device_price`)
--   r3(`city`, `city_rank`, `residence`)
--   r4(`adv_id`, `adv_prim_id`, `inter_type_cd`, `spread_app_id`, `tags`, `task_id`)
--   r5(main table)
--   r0(residual table for union)
--
-- Join graph:
--   r5 joins with r1 using (`uid`)
--   r5 joins with r4 using (`adv_id`)
--   r1 joins with r2 using (`device_name`)
--   r1 joins with r3 using (`city`)
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve all exposure records of one user from the main table,
-- e.g., when analyzing the recommendation logs associated with
-- a specific user identifier.
SELECT
    `id`,
    `uid`,
    `adv_id`,
    `age`,
    `app_score`,
    `pt_d`
FROM r5
WHERE `uid` = 1406853

UNION ALL

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
-- Inspect one lookup entry in the device dictionary table,
-- e.g., when checking the device price associated with a given
-- device code.
SELECT DISTINCT
    `device_name`,
    `device_price`
FROM (
    SELECT
        `device_name`,
        `device_price`
    FROM r2
    WHERE `device_name` = 56

    UNION ALL

    SELECT
        `device_name`,
        `device_price`
    FROM r0
    WHERE `device_name` = 56
) AS t;


-- Q3:
-- Business scenario:
-- Filter records on a non-FK regular attribute in the main table,
-- e.g., when profiling users in a certain encoded age range.
SELECT
    `id`,
    `uid`,
    `adv_id`,
    `age`,
    `app_score`,
    `net_type`
FROM r5
WHERE `age` BETWEEN 4 AND 7

UNION ALL

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
-- Join Queries
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve user-side profile information together with device metadata,
-- i.e., a lightweight one-hop lookup around the user profile table.
SELECT
    r1.`uid`,
    r1.`device_name`,
    r2.`device_price`,
    r1.`city`,
    r1.`gender`
FROM r1
JOIN r2 USING (`device_name`)
WHERE r1.`uid` = 1406853

UNION ALL

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
-- Reconstruct exposure records filtered by indexed FK attributes,
-- e.g., when inspecting one user's interactions with a specific ad.
SELECT
    r5.`id`,
    r5.`uid`,
    r1.`city`,
    r5.`adv_id`,
    r4.`task_id`,
    r4.`tags`,
    r5.`app_score`
FROM r5
JOIN r1 USING (`uid`)
JOIN r4 USING (`adv_id`)
WHERE r5.`uid` = 1406853
  AND r5.`adv_id` = 4407

UNION ALL

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
-- Reconstruct records with partially indexed predicates,
-- e.g., when analyzing one indexed advertisement together with
-- a non-index age filter.
SELECT
    r5.`id`,
    r5.`uid`,
    r1.`city`,
    r3.`city_rank`,
    r5.`adv_id`,
    r4.`task_id`,
    r5.`age`,
    r5.`app_score`
FROM r5
JOIN r1 USING (`uid`)
JOIN r3 USING (`city`)
JOIN r4 USING (`adv_id`)
WHERE r5.`adv_id` = 4407
  AND r5.`age` BETWEEN 4 AND 7

UNION ALL

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
FROM (
    SELECT `adv_id`
    FROM r5

    UNION ALL

    SELECT `adv_id`
    FROM r0
) AS t
GROUP BY `adv_id`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average app score by city rank,
-- e.g., to compare engagement quality across different city tiers.
SELECT
    `city_rank`,
    AVG(`app_score`) AS avg_app_score
FROM (
    SELECT
        r3.`city_rank`,
        r5.`app_score`
    FROM r5
    JOIN r1 USING (`uid`)
    JOIN r3 USING (`city`)

    UNION ALL

    SELECT
        `city_rank`,
        `app_score`
    FROM r0
) AS t
GROUP BY `city_rank`
ORDER BY avg_app_score DESC;


-- Q9:
-- Business scenario:
-- Identify the top device codes with the highest average app score
-- under one indexed advertisement group.
SELECT
    `device_name`,
    AVG(`app_score`) AS avg_app_score
FROM (
    SELECT
        r1.`device_name`,
        r5.`app_score`
    FROM r5
    JOIN r1 USING (`uid`)
    JOIN r2 USING (`device_name`)
    WHERE r5.`adv_id` = 4407

    UNION ALL

    SELECT
        `device_name`,
        `app_score`
    FROM r0
    WHERE `adv_id` = 4407
) AS t
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
CREATE TEMPORARY TABLE tmp_q11 AS
SELECT
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
FROM (
    SELECT
        r5.`id`,
        r5.`uid`,
        r4.`task_id`,
        r5.`adv_id`,
        r5.`creat_type_cd`,
        r4.`adv_prim_id`,
        r5.`dev_id`,
        r4.`inter_type_cd`,
        r5.`slot_id`,
        r4.`spread_app_id`,
        r4.`tags`,
        r5.`app_first_class`,
        r5.`app_second_class`,
        r5.`age`,
        r1.`city`,
        r1.`device_name`,
        r1.`device_size`,
        r1.`career`,
        r1.`gender`,
        r5.`net_type`,
        r3.`residence`,
        r5.`his_app_size`,
        r5.`his_on_shelf_time`,
        r5.`app_score`,
        r1.`emui_dev`,
        r5.`list_time`,
        r2.`device_price`,
        r1.`up_life_duration`,
        r1.`up_membership_grade`,
        r5.`membership_life_duration`,
        r1.`consume_purchase`,
        r5.`communication_onlinerate`,
        r5.`communication_avgonline_30d`,
        r5.`indu_name`,
        r5.`pt_d`
    FROM r5
    JOIN r1 USING (`uid`)
    JOIN r2 USING (`device_name`)
    JOIN r3 USING (`city`)
    JOIN r4 USING (`adv_id`)
    WHERE r5.`id` = 900000001

    UNION ALL

    SELECT
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
    FROM r0
    WHERE `id` = 900000001
) AS src;

DELETE FROM r5
WHERE `id` = 900000001;

DELETE FROM r0
WHERE `id` = 900000001;

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
)
SELECT
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
    92 AS `app_score`,
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
FROM tmp_q11;

DROP TEMPORARY TABLE tmp_q11;


-- Q12:
-- Business scenario:
-- Delete one specific exposure record,
-- e.g., when an invalid or duplicated profile must be removed.
DELETE FROM r5
WHERE `id` = 900000001;

DELETE FROM r0
WHERE `id` = 900000001;