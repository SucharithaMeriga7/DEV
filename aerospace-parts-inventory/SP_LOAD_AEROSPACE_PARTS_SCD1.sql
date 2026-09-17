/*=========================================================
Object Name : SP_LOAD_AEROSPACE_PARTS_SCD1
Purpose     : Aerospace Parts SCD1 pipeline with RISK_SCORE
Author      : SDLC_AGENT
=========================================================*/
CREATE OR REPLACE PROCEDURE GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.SP_LOAD_AEROSPACE_PARTS_SCD1()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    -- SECTION 1: Variables
    v_start_ts      TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    v_run_id        VARCHAR       := UUID_STRING();
    v_last_load_ts  TIMESTAMP_NTZ;
    v_src_count     INTEGER := 0;
    v_dedup_count   INTEGER := 0;
    v_insert_count  INTEGER := 0;
    v_update_count  INTEGER := 0;
    v_delete_count  INTEGER := 0;
    v_invalid_count INTEGER := 0;
    v_tgt_before    INTEGER := 0;
    v_tgt_after     INTEGER := 0;
    v_result        VARCHAR;

BEGIN
    USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

    -- SECTION 2: Source Processing
    SELECT COALESCE(MAX(DW_UPDATED_TIMESTAMP), '1900-01-01'::TIMESTAMP_NTZ)
    INTO :v_last_load_ts
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET;

    SELECT COUNT(*) INTO :v_src_count
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_SOURCE
    WHERE UPDATED_AT > :v_last_load_ts;

    SELECT COUNT(*) INTO :v_tgt_before
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET;

    -- Deduplicated staging with transformations and RISK_SCORE
    CREATE OR REPLACE TEMPORARY TABLE STAGE_AEROSPACE_PARTS AS
    SELECT
        PART_NUMBER,
        INITCAP(MANUFACTURER)                           AS MANUFACTURER,
        NULLIF(WEIGHT_KG, 0)                            AS WEIGHT_KG,
        UNIT_PRICE_USD,
        LIFECYCLE_STATUS,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        STOCK_QUANTITY,
        REORDER_LEVEL,
        SUPPLIER_ID,
        UPDATED_AT,
        CASE
            WHEN CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 90  THEN 'High Risk'
            WHEN CERTIFICATION_STATUS = 'Pending' OR  LEAD_TIME_DAYS > 120 THEN 'Medium Risk'
            WHEN CERTIFICATION_STATUS IN ('FAA','EASA','Dual')
                 AND LEAD_TIME_DAYS <= 90                                   THEN 'Low Risk'
            ELSE 'Medium Risk'
        END                                             AS RISK_SCORE
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) AS RN
        FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_SOURCE
        WHERE UPDATED_AT > :v_last_load_ts
    ) WHERE RN = 1;

    SELECT COUNT(*) INTO :v_dedup_count FROM STAGE_AEROSPACE_PARTS;

    -- SECTION 3: Data Validation
    CREATE OR REPLACE TEMPORARY TABLE STAGE_INVALID AS
    SELECT * FROM STAGE_AEROSPACE_PARTS
    WHERE PART_NUMBER IS NULL OR TRIM(PART_NUMBER) = '';

    SELECT COUNT(*) INTO :v_invalid_count FROM STAGE_INVALID;

    CREATE OR REPLACE TEMPORARY TABLE STAGE_VALID AS
    SELECT * FROM STAGE_AEROSPACE_PARTS
    WHERE PART_NUMBER IS NOT NULL AND TRIM(PART_NUMBER) != '';

    -- SECTION 4: Merge Logic
    MERGE INTO GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET T
    USING STAGE_VALID S ON T.PART_NUMBER = S.PART_NUMBER
    WHEN MATCHED THEN UPDATE SET
        T.MANUFACTURER         = S.MANUFACTURER,
        T.WEIGHT_KG            = S.WEIGHT_KG,
        T.UNIT_PRICE_USD       = S.UNIT_PRICE_USD,
        T.LIFECYCLE_STATUS     = S.LIFECYCLE_STATUS,
        T.CERTIFICATION_STATUS = S.CERTIFICATION_STATUS,
        T.LEAD_TIME_DAYS       = S.LEAD_TIME_DAYS,
        T.STOCK_QUANTITY       = S.STOCK_QUANTITY,
        T.REORDER_LEVEL        = S.REORDER_LEVEL,
        T.SUPPLIER_ID          = S.SUPPLIER_ID,
        T.RISK_SCORE           = S.RISK_SCORE,
        T.DW_UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, MANUFACTURER, WEIGHT_KG, UNIT_PRICE_USD,
        LIFECYCLE_STATUS, CERTIFICATION_STATUS, LEAD_TIME_DAYS,
        STOCK_QUANTITY, REORDER_LEVEL, SUPPLIER_ID, RISK_SCORE,
        DW_INSERT_TIMESTAMP, DW_UPDATED_TIMESTAMP
    ) VALUES (
        S.PART_NUMBER, S.MANUFACTURER, S.WEIGHT_KG, S.UNIT_PRICE_USD,
        S.LIFECYCLE_STATUS, S.CERTIFICATION_STATUS, S.LEAD_TIME_DAYS,
        S.STOCK_QUANTITY, S.REORDER_LEVEL, S.SUPPLIER_ID, S.RISK_SCORE,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );

    -- Capture insert/update counts
    SELECT COUNT(*) INTO :v_insert_count
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET
    WHERE DW_INSERT_TIMESTAMP >= :v_start_ts;

    SELECT COUNT(*) INTO :v_update_count
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET
    WHERE DW_UPDATED_TIMESTAMP >= :v_start_ts
      AND DW_INSERT_TIMESTAMP  <  :v_start_ts;

    -- Soft-delete parts absent from source
    UPDATE GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET T
    SET T.LIFECYCLE_STATUS     = 'Decommissioned',
        T.DW_UPDATED_TIMESTAMP = CURRENT_TIMESTAMP()
    WHERE T.LIFECYCLE_STATUS != 'Decommissioned'
      AND NOT EXISTS (
          SELECT 1 FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_SOURCE S
          WHERE S.PART_NUMBER = T.PART_NUMBER
      );

    SELECT COUNT(*) INTO :v_delete_count
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET
    WHERE LIFECYCLE_STATUS = 'Decommissioned'
      AND DW_UPDATED_TIMESTAMP >= :v_start_ts;

    SELECT COUNT(*) INTO :v_tgt_after
    FROM GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.AEROSPACE_PARTS_TARGET;

    -- SECTION 5: Reconciliation
    INSERT INTO GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.ETL_RECONCILIATION_LOG (
        RUN_ID, PROCEDURE_NAME, START_TIMESTAMP, END_TIMESTAMP,
        SOURCE_COUNT, DEDUP_COUNT, INVALID_COUNT,
        INSERT_COUNT, UPDATE_COUNT, DELETE_COUNT,
        TARGET_BEFORE, TARGET_AFTER, STATUS
    ) VALUES (
        :v_run_id, 'SP_LOAD_AEROSPACE_PARTS_SCD1', :v_start_ts, CURRENT_TIMESTAMP(),
        :v_src_count, :v_dedup_count, :v_invalid_count,
        :v_insert_count, :v_update_count, :v_delete_count,
        :v_tgt_before, :v_tgt_after, 'SUCCESS'
    );

    v_result := OBJECT_CONSTRUCT(
        'run_id',        :v_run_id,
        'status',        'SUCCESS',
        'src_count',     :v_src_count,
        'dedup_count',   :v_dedup_count,
        'invalid_count', :v_invalid_count,
        'insert_count',  :v_insert_count,
        'update_count',  :v_update_count,
        'delete_count',  :v_delete_count,
        'tgt_before',    :v_tgt_before,
        'tgt_after',     :v_tgt_after
    )::VARCHAR;

    -- SECTION 6: Error Handling
    RETURN :v_result;

EXCEPTION WHEN OTHER THEN
    INSERT INTO GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.ETL_RECONCILIATION_LOG (
        RUN_ID, PROCEDURE_NAME, START_TIMESTAMP, END_TIMESTAMP,
        SOURCE_COUNT, DEDUP_COUNT, INVALID_COUNT,
        INSERT_COUNT, UPDATE_COUNT, DELETE_COUNT,
        TARGET_BEFORE, TARGET_AFTER, STATUS
    ) VALUES (
        :v_run_id, 'SP_LOAD_AEROSPACE_PARTS_SCD1', :v_start_ts, CURRENT_TIMESTAMP(),
        :v_src_count, :v_dedup_count, :v_invalid_count,
        :v_insert_count, :v_update_count, :v_delete_count,
        :v_tgt_before, :v_tgt_after, 'FAILED: ' || SQLERRM
    );
    RETURN OBJECT_CONSTRUCT('error', SQLERRM)::VARCHAR;
END;
$$;

-- Scheduled Task: daily 05:00 UTC
CREATE OR REPLACE TASK GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.TASK_LOAD_AEROSPACE_PARTS_SCD1
    WAREHOUSE = SNOWFLAKE_LEARNING_WH
    SCHEDULE  = 'USING CRON 0 5 * * * UTC'
AS
CALL GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.SP_LOAD_AEROSPACE_PARTS_SCD1();

ALTER TASK GEN_AI_POC_SNOWFLAKECOE.SDLC_WIZARD.TASK_LOAD_AEROSPACE_PARTS_SCD1 RESUME;