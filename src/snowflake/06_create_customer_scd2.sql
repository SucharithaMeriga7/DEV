BEGIN
    -- SCD Type 2 table for customer dimension
    CREATE TABLE IF NOT EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_SCD2 (
        CUSTOMER_SCD2_KEY   NUMBER AUTOINCREMENT START 1 INCREMENT 1,
        CUSTID              VARCHAR(50),
        NAME                VARCHAR(255),
        EMAILID             VARCHAR(255),
        REGION              VARCHAR(100),
        IS_CURRENT          BOOLEAN DEFAULT TRUE,
        EFFECTIVE_FROM      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        EFFECTIVE_TO        TIMESTAMP_NTZ DEFAULT '9999-12-31 00:00:00'::TIMESTAMP_NTZ
    );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'CUSTOMER_SCD2 table created successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '06_create_customer_scd2')::VARCHAR;
END;