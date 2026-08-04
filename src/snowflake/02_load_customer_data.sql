BEGIN
    -- Truncate customer table before fresh load
    TRUNCATE TABLE IF EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER;

    -- Load customer data from stage
    COPY INTO gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER (
        CUSTID,
        NAME,
        EMAILID,
        REGION
    )
    FROM @gen_ai_poc_snowflakecoe.sdlc_wizard_stage/customerdata
    FILE_FORMAT = (
        TYPE = 'CSV'
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        TRIM_SPACE = TRUE
    )
    ON_ERROR = CONTINUE;

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'Customer data loaded successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '02_load_customer_data')::VARCHAR;
END;