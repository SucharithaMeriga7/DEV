/*=========================================================
Object Name : QA_AEROSPACE_PARTS_PIPELINE
Purpose     : QA acceptance criteria queries
Database    : GEN_AI_POC_SNOWFLAKECOE
Schema      : SDLC_WIZARD
Warehouse   : SNOWFLAKE_LEARNING_WH
SP          : SP_LOAD_AEROSPACE_PARTS_SCD1
AC Range    : AC-001 through AC-010
=========================================================*/
USE DATABASE GEN_AI_POC_SNOWFLAKECOE;
USE SCHEMA SDLC_WIZARD;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- ============================================================
-- AC-001: TARGET TABLE EXISTS AND IS ACCESSIBLE
-- PASS: Returns row count >= 0 with no errors
-- ============================================================
SELECT
    'AC-001'                                AS acceptance_criteria,
    'TARGET TABLE EXISTS AND IS ACCESSIBLE' AS description,
    COUNT(*)                                AS row_count,
    CASE WHEN COUNT(*) >= 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM AEROSPACE_PARTS_TARGET;

-- ============================================================
-- AC-002: SCHEMA VALIDATION — REQUIRED COLUMNS PRESENT
-- PASS: All 14 expected columns returned
-- ============================================================
SELECT
    'AC-002'                                  AS acceptance_criteria,
    'SCHEMA VALIDATION — REQUIRED COLUMNS'    AS description,
    COUNT(*)                                  AS column_count,
    CASE WHEN COUNT(*) = 14 THEN 'PASS' ELSE 'FAIL' END AS result
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SDLC_WIZARD'
  AND TABLE_NAME   = 'AEROSPACE_PARTS_TARGET'
  AND COLUMN_NAME IN (
      'PART_NUMBER','PART_NAME','MANUFACTURER','CATEGORY',
      'WEIGHT_KG','UNIT_COST','LEAD_TIME_DAYS','CERTIFICATION_STATUS',
      'STOCK_QUANTITY','REORDER_LEVEL','STATUS','RISK_SCORE',
      'DW_INSERT_TIMESTAMP','DW_UPDATED_AT'
  );

-- ============================================================
-- AC-003: NO DUPLICATE PART_NUMBER IN TARGET
-- PASS: duplicate_count = 0
-- ============================================================
SELECT
    'AC-003'                              AS acceptance_criteria,
    'NO DUPLICATE PART_NUMBER IN TARGET'  AS description,
    COUNT(*)                              AS duplicate_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT PART_NUMBER
    FROM AEROSPACE_PARTS_TARGET
    GROUP BY PART_NUMBER
    HAVING COUNT(*) > 1
);

-- ============================================================
-- AC-004: MANUFACTURER INITCAP TRANSFORMATION APPLIED
-- PASS: no_initcap_count = 0
-- ============================================================
SELECT
    'AC-004'                                    AS acceptance_criteria,
    'MANUFACTURER INITCAP TRANSFORMATION'       AS description,
    COUNT(*)                                    AS no_initcap_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM AEROSPACE_PARTS_TARGET
WHERE MANUFACTURER IS NOT NULL
  AND MANUFACTURER != INITCAP(MANUFACTURER);

-- ============================================================
-- AC-005: WEIGHT_KG — NO ZERO VALUES (NULLIF APPLIED)
-- PASS: zero_weight_count = 0
-- ============================================================
SELECT
    'AC-005'                              AS acceptance_criteria,
    'WEIGHT_KG NO ZERO VALUES'            AS description,
    COUNT(*)                              AS zero_weight_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM AEROSPACE_PARTS_TARGET
WHERE WEIGHT_KG = 0;

-- ============================================================
-- AC-006: RISK_SCORE VALID VALUES ONLY
-- PASS: invalid_risk_count = 0
-- ============================================================
SELECT
    'AC-006'                          AS acceptance_criteria,
    'RISK_SCORE VALID VALUES ONLY'    AS description,
    COUNT(*)                          AS invalid_risk_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM AEROSPACE_PARTS_TARGET
WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk')
   OR RISK_SCORE IS NULL;

-- ============================================================
-- AC-007: RISK_SCORE LOGIC — HIGH RISK VALIDATION
-- PASS: misclassified_high_risk = 0
-- ============================================================
SELECT
    'AC-007'                              AS acceptance_criteria,
    'HIGH RISK CLASSIFICATION ACCURACY'   AS description,
    COUNT(*)                              AS misclassified_high_risk,
    CASE WHEN COUNT(*) = 0