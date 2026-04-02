-- =========================================================
-- CRIME workload for query performance evaluation
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
-- Retrieve incident records under one indexed crime category,
-- e.g., when investigators inspect all incidents with a specific
-- crime code from the large table.
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
-- Inspect one lookup entry for a crime code and its description,
-- e.g., when the system checks the textual description associated
-- with a specific crime code.
SELECT DISTINCT
    `Crime Code`,
    `CrimeCodeDescription`
FROM r0
WHERE `Crime Code` = 624;


-- Q3:
-- Business scenario:
-- Filter incidents on a non-index regular attribute,
-- e.g., when analysts retrieve incidents involving young adult victims.
SELECT
    `Digital Record Number`,
    `Victim Age`,
    `Victim Gender`,
    `Date of Occurrence`,
    `ModusOperandiCodes`
FROM r0
WHERE `Victim Age` BETWEEN 18 AND 30;



-- =========================================================
-- Queries corresponding to join-based lookups in decomposed schema
-- =========================================================

-- Q4:
-- Business scenario:
-- Retrieve police area metadata for one subarea,
-- e.g., when translating a subarea identifier into its
-- corresponding area name and area code.
SELECT DISTINCT
    `SubArea Number`,
    `Area Name`,
    `AreaCode`
FROM r0
WHERE `SubArea Number` = 12;


-- Q5:
-- Business scenario:
-- Retrieve incident metadata filtered by indexed category/status attributes,
-- e.g., when investigators inspect a specific crime code under
-- a specific case status.
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
-- Retrieve incident details with partially selective predicates,
-- e.g., when analysts inspect one indexed crime category but also
-- restrict results to a non-index victim-age range.
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
FROM r0
GROUP BY `Status`, `Status Desc`
ORDER BY cnt DESC;


-- Q8:
-- Business scenario:
-- Measure average victim age by premise description,
-- e.g., to compare victim age patterns across incident locations.
SELECT
    `PremiseDescription`,
    AVG(`Victim Age`) AS avg_victim_age
FROM r0
WHERE `Victim Age` > 0
GROUP BY `PremiseDescription`
ORDER BY avg_victim_age DESC;


-- Q9:
-- Business scenario:
-- Identify the top police areas with the largest number of ongoing cases,
-- e.g., for workload analysis across geographic regions.
SELECT
    `Area Name`,
    COUNT(*) AS cnt
FROM r0
WHERE `Status` = 'IC'
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
UPDATE r0
SET
    `Victim Age` = 31,
    `Status` = 'AA',
    `Status Desc` = 'Adult Arrest'
WHERE `Digital Record Number` = 190326475;


-- Q12:
-- Business scenario:
-- Delete one specific incident record,
-- e.g., when an invalid, duplicated, or revoked case log
-- must be removed from storage.
DELETE FROM r0
WHERE `Digital Record Number` = 190326476;