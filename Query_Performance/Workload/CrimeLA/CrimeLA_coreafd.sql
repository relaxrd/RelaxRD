-- =========================================================
-- CRIME workload for query performance evaluation
-- Decomposed schema:
--   r1(`Area Name`, `AreaCode`)
--   r2(`Crime Code`, `CrimeCodeDescription`)
--   r3(`Premise Code`, `PremiseDescription`)
--   r4(`Status`, `Status Desc`)
--   r5(`Area Name`, `SubArea Number`)
--   r6(`Weapon Description`, `Weapon Used Code`)
--   r7(main table)
--   r0(residual table for union)
--
-- Join graph:
--   r7 joins with r2/r3/r4/r5/r6
--   r5 joins with r1
-- =========================================================


-- =========================================================
-- No-Join Queries
-- =========================================================

-- Q1:
-- Business scenario:
-- Retrieve incident records under one indexed crime category,
-- e.g., when investigators inspect all incidents with a specific
-- crime code from the main fact table.
SELECT
    `Digital Record Number`,
    `Crime Code`,
    `Date of Occurrence`,
    `Time of Occurrence`,
    `Victim Age`,
    `Victim Gender`
FROM r7
WHERE `Crime Code` = 624

UNION ALL

SELECT
    `Digital Record Number`,
    `Crime Code`,
    `Date of Occurrence`,
    `Time of Occurrence`,
    `Victim Age`,
    `Victim Gender`
FROM r0
WHERE `Crime Code` = 624;


-- Q2:
-- Business scenario:
-- Inspect one lookup entry in a small dictionary table,
-- e.g., when the system checks the description associated
-- with a specific crime code.
SELECT DISTINCT
    `Crime Code`,
    `CrimeCodeDescription`
FROM (
    SELECT `Crime Code`, `CrimeCodeDescription`
    FROM r2
    WHERE `Crime Code` = 624

    UNION ALL

    SELECT `Crime Code`, `CrimeCodeDescription`
    FROM r0
    WHERE `Crime Code` = 624
) AS t;


-- Q3:
-- Business scenario:
-- Filter incidents on a non-index regular attribute in the main table,
-- e.g., when analysts retrieve incidents involving young adult victims.
SELECT
    `Digital Record Number`,
    `Victim Age`,
    `Victim Gender`,
    `Date of Occurrence`,
    `ModusOperandiCodes`
FROM r7
WHERE `Victim Age` BETWEEN 18 AND 30

UNION ALL

SELECT
    `Digital Record Number`,
    `Victim Age`,
    `Victim Gender`,
    `Date of Occurrence`,
    `ModusOperandiCodes`
FROM r0
WHERE `Victim Age` BETWEEN 18 AND 30;



-- =========================================================
-- Join Queries
-- =========================================================

-- Q4:
-- Business scenario:
-- Join two decomposed small tables to resolve the police area metadata
-- of one subarea, e.g., when translating a subarea identifier into its
-- corresponding area name and area code.
SELECT
    r5.`SubArea Number`,
    r5.`Area Name`,
    r1.`AreaCode`
FROM r5
JOIN r1 USING (`Area Name`)
WHERE r5.`SubArea Number` = 12

UNION ALL

SELECT
    `SubArea Number`,
    `Area Name`,
    `AreaCode`
FROM r0
WHERE `SubArea Number` = 12;


-- Q5:
-- Business scenario:
-- Reconstruct incident metadata with several dimension tables,
-- while filtering on indexed foreign-key attributes,
-- e.g., when investigators inspect a specific crime code under
-- a specific case status.
SELECT
    r7.`Digital Record Number`,
    r7.`Crime Code`,
    r2.`CrimeCodeDescription`,
    r7.`Status`,
    r4.`Status Desc`,
    r7.`Date of Occurrence`,
    r7.`Time of Occurrence`
FROM r7
JOIN r2 USING (`Crime Code`)
JOIN r4 USING (`Status`)
WHERE r7.`Crime Code` = 624
  AND r7.`Status` = 'IC'

UNION ALL

SELECT
    `Digital Record Number`,
    `Crime Code`,
    `CrimeCodeDescription`,
    `Status`,
    `Status Desc`,
    `Date of Occurrence`,
    `Time of Occurrence`
FROM r0
WHERE `Crime Code` = 624
  AND `Status` = 'IC';


-- Q6:
-- Business scenario:
-- Reconstruct incident details with partially indexed predicates,
-- e.g., when analysts inspect one indexed crime category but also
-- restrict results to a non-index victim-age range.
SELECT
    r7.`Digital Record Number`,
    r7.`Crime Code`,
    r2.`CrimeCodeDescription`,
    r7.`Premise Code`,
    r3.`PremiseDescription`,
    r7.`Status`,
    r4.`Status Desc`,
    r7.`Victim Age`
FROM r7
JOIN r2 USING (`Crime Code`)
JOIN r3 USING (`Premise Code`)
JOIN r4 USING (`Status`)
WHERE r7.`Crime Code` = 624
  AND r7.`Victim Age` BETWEEN 18 AND 30

UNION ALL

SELECT
    `Digital Record Number`,
    `Crime Code`,
    `CrimeCodeDescription`,
    `Premise Code`,
    `PremiseDescription`,
    `Status`,
    `Status Desc`,
    `Victim Age`
FROM r0
WHERE `Crime Code` = 624
  AND `Victim Age` BETWEEN 18 AND 30;



-- =========================================================
-- Analytical Queries
-- =========================================================

-- Q7:
-- Business scenario:
-- Summarize incident volume by indexed status code,
-- e.g., to understand how cases are distributed across major
-- processing states.
SELECT
    `Status`,
    `Status Desc`,
    COUNT(*) AS cnt
FROM (
    SELECT
        r7.`Status`,
        r4.`Status Desc`
    FROM r7
    JOIN r4 USING (`Status`)

    UNION ALL

    SELECT
        `Status`,
        `Status Desc`
    FROM r0
) AS t
GROUP BY `Status`, `Status Desc`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average victim age by premise description,
-- e.g., to compare victim age patterns across incident locations.
SELECT
    `PremiseDescription`,
    AVG(`Victim Age`) AS avg_victim_age
FROM (
    SELECT
        r3.`PremiseDescription`,
        r7.`Victim Age`
    FROM r7
    JOIN r3 USING (`Premise Code`)
    WHERE r7.`Victim Age` > 0

    UNION ALL

    SELECT
        `PremiseDescription`,
        `Victim Age`
    FROM r0
    WHERE `Victim Age` > 0
) AS t
GROUP BY `PremiseDescription`
ORDER BY avg_victim_age DESC;


-- Q9:
-- Business scenario:
-- Identify the top police areas with the largest number of ongoing cases,
-- e.g., for workload analysis across geographic regions.
SELECT
    `Area Name`,
    COUNT(*) AS cnt
FROM (
    SELECT
        r5.`Area Name`
    FROM r7
    JOIN r5 USING (`SubArea Number`)
    WHERE r7.`Status` = 'IC'

    UNION ALL

    SELECT
        `Area Name`
    FROM r0
    WHERE `Status` = 'IC'
) AS t
GROUP BY `Area Name`
ORDER BY cnt DESC
LIMIT 10;



-- =========================================================
-- Write Queries
-- =========================================================

-- Q10:
-- Business scenario:
-- Insert one newly arrived incident record,
-- e.g., when a fresh crime event is appended to the logging system.
INSERT INTO r0 (
    `Digital Record Number`,
    `Date Reported`,
    `Date of Occurrence`,
    `Time of Occurrence`,
    `AreaCode`,
    `Area Name`,
    `SubArea Number`,
    `Crime Code`,
    `CrimeCodeDescription`,
    `ModusOperandiCodes`,
    `Victim Age`,
    `Victim Gender`,
    `Victim OriginalCountry`,
    `Premise Code`,
    `PremiseDescription`,
    `Weapon Used Code`,
    `Weapon Description`,
    `Status`,
    `Status Desc`,
    `Latitude`,
    `Longitude`,
    `Location`
) VALUES (
    990000001,
    '2025-03-01',
    '2025-02-28',
    2215,
    12,
    '77th Street',
    12,
    624,
    'BATTERY - SIMPLE ASSAULT',
    '0400',
    29,
    'M',
    'United-States',
    101,
    'STREET',
    400,
    'STRONG-ARM (HANDS, FIST, FEET OR BODILY FORCE)',
    'IC',
    'Invest Cont',
    34.0522,
    -118.2437,
    '(34.0522, -118.2437)'
);


-- Q11:
-- Business scenario:
-- Update one specific incident record,
-- e.g., when victim information and case status are corrected
-- after additional investigation.

CREATE TEMPORARY TABLE tmp_q11 AS
SELECT
    `Digital Record Number`,
    `Date Reported`,
    `Date of Occurrence`,
    `Time of Occurrence`,
    `AreaCode`,
    `Area Name`,
    `SubArea Number`,
    `Crime Code`,
    `CrimeCodeDescription`,
    `ModusOperandiCodes`,
    `Victim Age`,
    `Victim Gender`,
    `Victim OriginalCountry`,
    `Premise Code`,
    `PremiseDescription`,
    `Weapon Used Code`,
    `Weapon Description`,
    `Status`,
    `Status Desc`,
    `Latitude`,
    `Longitude`,
    `Location`
FROM (
    SELECT
        r7.`Digital Record Number`,
        r7.`Date Reported`,
        r7.`Date of Occurrence`,
        r7.`Time of Occurrence`,
        r1.`AreaCode`,
        r5.`Area Name`,
        r7.`SubArea Number`,
        r7.`Crime Code`,
        r2.`CrimeCodeDescription`,
        r7.`ModusOperandiCodes`,
        r7.`Victim Age`,
        r7.`Victim Gender`,
        r7.`Victim OriginalCountry`,
        r7.`Premise Code`,
        r3.`PremiseDescription`,
        r6.`Weapon Used Code`,
        r7.`Weapon Description`,
        r7.`Status`,
        r4.`Status Desc`,
        r7.`Latitude`,
        r7.`Longitude`,
        r7.`Location`
    FROM r7
    JOIN r2 USING (`Crime Code`)
    JOIN r3 USING (`Premise Code`)
    JOIN r4 USING (`Status`)
    JOIN r5 USING (`SubArea Number`)
    JOIN r1 USING (`Area Name`)
    JOIN r6 USING (`Weapon Description`)
    WHERE r7.`Digital Record Number` = 190326475

    UNION ALL

    SELECT
        `Digital Record Number`,
        `Date Reported`,
        `Date of Occurrence`,
        `Time of Occurrence`,
        `AreaCode`,
        `Area Name`,
        `SubArea Number`,
        `Crime Code`,
        `CrimeCodeDescription`,
        `ModusOperandiCodes`,
        `Victim Age`,
        `Victim Gender`,
        `Victim OriginalCountry`,
        `Premise Code`,
        `PremiseDescription`,
        `Weapon Used Code`,
        `Weapon Description`,
        `Status`,
        `Status Desc`,
        `Latitude`,
        `Longitude`,
        `Location`
    FROM r0
    WHERE `Digital Record Number` = 190326475
) AS src;

DELETE FROM r7
WHERE `Digital Record Number` = 190326475;

DELETE FROM r0
WHERE `Digital Record Number` = 190326475;

INSERT INTO r0 (
    `Digital Record Number`,
    `Date Reported`,
    `Date of Occurrence`,
    `Time of Occurrence`,
    `AreaCode`,
    `Area Name`,
    `SubArea Number`,
    `Crime Code`,
    `CrimeCodeDescription`,
    `ModusOperandiCodes`,
    `Victim Age`,
    `Victim Gender`,
    `Victim OriginalCountry`,
    `Premise Code`,
    `PremiseDescription`,
    `Weapon Used Code`,
    `Weapon Description`,
    `Status`,
    `Status Desc`,
    `Latitude`,
    `Longitude`,
    `Location`
)
SELECT
    `Digital Record Number`,
    `Date Reported`,
    `Date of Occurrence`,
    `Time of Occurrence`,
    `AreaCode`,
    `Area Name`,
    `SubArea Number`,
    `Crime Code`,
    `CrimeCodeDescription`,
    `ModusOperandiCodes`,
    31 AS `Victim Age`,
    `Victim Gender`,
    `Victim OriginalCountry`,
    `Premise Code`,
    `PremiseDescription`,
    `Weapon Used Code`,
    `Weapon Description`,
    'AA' AS `Status`,
    'Adult Arrest' AS `Status Desc`,
    `Latitude`,
    `Longitude`,
    `Location`
FROM tmp_q11;

DROP TEMPORARY TABLE tmp_q11;


-- Q12:
-- Business scenario:
-- Delete one specific incident record,
-- e.g., when an invalid, duplicated, or revoked case log
-- must be removed from storage.
DELETE FROM r7
WHERE `Digital Record Number` = 190326476;

DELETE FROM r0
WHERE `Digital Record Number` = 190326476;