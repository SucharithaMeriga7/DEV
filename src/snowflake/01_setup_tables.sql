BEGIN
    -- Create customer staging/landing table
    CREATE TABLE IF NOT EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER (
        CUSTID          VARCHAR(50),
        NAME            VARCHAR(255),
        EMAILID         VARCHAR(255),
        REGION          VARCHAR(100)
    );

    -- Create order table (order is a reserved word, must be quoted)
    CREATE TABLE IF NOT EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard."order" (
        ORDERID         VARCHAR(50),
        CUSTID          VARCHAR(50),
        ITEMNAME        VARCHAR(255),
        PRICEPERUNIT    NUMBER(18,4),
        QTY             NUMBER(18,0),
        ORDER_DATE      DATE,
        STARTDATE       DATE,
        ENDDATE         DATE,
        ISACTIVE        VARCHAR(10)
    );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'Base tables created successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '01_setup_tables')::VARCHAR;
END;