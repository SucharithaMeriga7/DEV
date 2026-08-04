BEGIN
    CREATE TABLE IF NOT EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMERAGGREGATESPEND (
        NAME            VARCHAR(255),
        ORDER_DATE      DATE,
        TOTAL_SPEND     NUMBER(18,4),
        LOAD_TIMESTAMP  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'CUSTOMERAGGREGATESPEND table created successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '10_create_customeraggregatespend')::VARCHAR;
END;