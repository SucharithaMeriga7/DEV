BEGIN
    -- Truncate order table before fresh load
    TRUNCATE TABLE IF EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard."order";

    -- Load order data from stage
    COPY INTO gen_ai_poc_snowflakecoe.sdlc_wizard."order" (
        ORDERID,
        CUSTID,
        ITEMNAME,
        PRICEPERUNIT,
        QTY,
        ORDER_DATE,
        STARTDATE,
        ENDDATE,
        ISACTIVE
    )
    FROM @gen_ai_poc_snowflakecoe.sdlc_wizard_stage/orderdata
    FILE_FORMAT = (
        TYPE = 'CSV'
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
        ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        TRIM_SPACE = TRUE
    )
    ON_ERROR = CONTINUE;

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'Order data loaded successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '03_load_order_data')::VARCHAR;
END;