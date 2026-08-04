BEGIN
    -- Remove null records (where key fields are null)
    DELETE FROM gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER
    WHERE CUSTID IS NULL
       OR TRIM(CUSTID) = ''
       OR NAME IS NULL
       OR TRIM(NAME) = '';

    -- Remove duplicates: keep the first occurrence based on CUSTID
    CREATE OR REPLACE TEMPORARY TABLE gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_DEDUPED AS
    SELECT
        CUSTID,
        NAME,
        EMAILID,
        REGION
    FROM gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CUSTID ORDER BY NAME) = 1;

    TRUNCATE TABLE gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER;

    INSERT INTO gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER (CUSTID, NAME, EMAILID, REGION)
    SELECT CUSTID, NAME, EMAILID, REGION
    FROM gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_DEDUPED;

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'Customer data cleaned successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '04_clean_customer_data')::VARCHAR;
END;