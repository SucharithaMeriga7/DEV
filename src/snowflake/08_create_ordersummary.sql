BEGIN
    CREATE TABLE IF NOT EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.ORDERSUMMARY (
        ORDERID         VARCHAR(50),
        CUSTID          VARCHAR(50),
        NAME            VARCHAR(255),
        EMAILID         VARCHAR(255),
        REGION          VARCHAR(100),
        ITEMNAME        VARCHAR(255),
        PRICEPERUNIT    NUMBER(18,4),
        QTY             NUMBER(18,0),
        TOTALAMOUNT     NUMBER(18,4),
        ORDER_DATE      DATE,
        STARTDATE       DATE,
        ENDDATE         DATE,
        ISACTIVE        VARCHAR(10),
        LOAD_TIMESTAMP  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'ORDERSUMMARY table created successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '08_create_ordersummary')::VARCHAR;
END;