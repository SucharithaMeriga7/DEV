BEGIN
    CREATE TABLE IF NOT EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.PIPELINE_LOG (
        LOG_ID          NUMBER AUTOINCREMENT START 1 INCREMENT 1,
        STEP_NAME       VARCHAR(200),
        STATUS          VARCHAR(50),
        MESSAGE         VARCHAR(4000),
        ROW_COUNT       NUMBER,
        LOG_TIMESTAMP   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'PIPELINE_LOG table created successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '12_create_log_table')::VARCHAR;
END;