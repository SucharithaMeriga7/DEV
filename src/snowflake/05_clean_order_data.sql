BEGIN
    -- Remove null records (where key fields are null)
    DELETE FROM gen_ai_poc_snowflakecoe.sdlc_wizard."order"
    WHERE ORDERID IS NULL
       OR TRIM(ORDERID) = ''
       OR CUSTID IS NULL
       OR TRIM(CUSTID) = '';

    -- Remove duplicates: keep the first occurrence based on ORDERID
    CREATE OR REPLACE TEMPORARY TABLE gen_ai_poc_snowflakecoe.sdlc_wizard.ORDER_DEDUPED AS
    SELECT
        ORDERID,
        CUSTID,
        ITEMNAME,
        PRICEPERUNIT,
        QTY,
        ORDER_DATE,
        STARTDATE,
        ENDDATE,
        ISACTIVE
    FROM gen_ai_poc_snowflakecoe.sdlc_wizard."order"
    QUALIFY ROW_NUMBER() OVER (PARTITION BY ORDERID ORDER BY ORDER_DATE DESC NULLS LAST) = 1;

    TRUNCATE TABLE gen_ai_poc_snowflakecoe.sdlc_wizard."order";

    INSERT INTO gen_ai_poc_snowflakecoe.sdlc_wizard."order" (
        ORDERID, CUSTID, ITEMNAME, PRICEPERUNIT, QTY, ORDER_DATE, STARTDATE, ENDDATE, ISACTIVE
    )
    SELECT ORDERID, CUSTID, ITEMNAME, PRICEPERUNIT, QTY, ORDER_DATE, STARTDATE, ENDDATE, ISACTIVE
    FROM gen_ai_poc_snowflakecoe.sdlc_wizard.ORDER_DEDUPED;

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'Order data cleaned successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '05_clean_order_data')::VARCHAR;
END;