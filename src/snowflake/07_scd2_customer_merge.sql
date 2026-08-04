BEGIN
    -- Step 1: Expire existing current records where source data has changed
    MERGE INTO gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_SCD2 AS TGT
    USING gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER AS SRC
        ON TGT.CUSTID = SRC.CUSTID
        AND TGT.IS_CURRENT = TRUE
    WHEN MATCHED
        AND (
            NVL(TGT.NAME, '~~') <> NVL(SRC.NAME, '~~')
            OR NVL(TGT.EMAILID, '~~') <> NVL(SRC.EMAILID, '~~')
            OR NVL(TGT.REGION, '~~') <> NVL(SRC.REGION, '~~')
        )
    THEN UPDATE
        SET TGT.IS_CURRENT = FALSE,
            TGT.EFFECTIVE_TO = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (CUSTID, NAME, EMAILID, REGION, IS_CURRENT, EFFECTIVE_FROM, EFFECTIVE_TO)
        VALUES (SRC.CUSTID, SRC.NAME, SRC.EMAILID, SRC.REGION, TRUE, CURRENT_TIMESTAMP(), '9999-12-31 00:00:00'::TIMESTAMP_NTZ);

    -- Step 2: Insert new current records for changed rows (the expired ones above need new active versions)
    INSERT INTO gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_SCD2 (
        CUSTID, NAME, EMAILID, REGION, IS_CURRENT, EFFECTIVE_FROM, EFFECTIVE_TO
    )
    SELECT
        SRC.CUSTID,
        SRC.NAME,
        SRC.EMAILID,
        SRC.REGION,
        TRUE,
        CURRENT_TIMESTAMP(),
        '9999-12-31 00:00:00'::TIMESTAMP_NTZ
    FROM gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER AS SRC
    INNER JOIN gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_SCD2 AS TGT
        ON SRC.CUSTID = TGT.CUSTID
        AND TGT.IS_CURRENT = FALSE
        AND TGT.EFFECTIVE_TO >= DATEADD('SECOND', -5, CURRENT_TIMESTAMP())
    WHERE NOT EXISTS (
        SELECT 1
        FROM gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_SCD2 AS CHK
        WHERE CHK.CUSTID = SRC.CUSTID
          AND CHK.IS_CURRENT = TRUE
    );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'SCD2 merge completed successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '07_scd2_customer_merge')::VARCHAR;
END;