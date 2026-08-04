BEGIN
    -- Merge joined customer + order data into ordersummary
    -- Handles SCD2-style: mark old records inactive, insert new active records
    MERGE INTO gen_ai_poc_snowflakecoe.sdlc_wizard.ORDERSUMMARY AS TGT
    USING (
        SELECT
            O.ORDERID,
            O.CUSTID,
            C.NAME,
            C.EMAILID,
            C.REGION,
            O.ITEMNAME,
            O.PRICEPERUNIT,
            O.QTY,
            (O.PRICEPERUNIT * O.QTY) AS TOTALAMOUNT,
            O.ORDER_DATE,
            O.STARTDATE,
            O.ENDDATE,
            O.ISACTIVE
        FROM gen_ai_poc_snowflakecoe.sdlc_wizard."order" AS O
        INNER JOIN gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER AS C
            ON O.CUSTID = C.CUSTID
        WHERE O.ORDERID IS NOT NULL
          AND O.CUSTID IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY O.ORDERID ORDER BY O.ORDER_DATE DESC NULLS LAST) = 1
    ) AS SRC
        ON TGT.ORDERID = SRC.ORDERID
    WHEN MATCHED
        AND (
            NVL(TGT.NAME, '~~') <> NVL(SRC.NAME, '~~')
            OR NVL(TGT.EMAILID, '~~') <> NVL(SRC.EMAILID, '~~')
            OR NVL(TGT.REGION, '~~') <> NVL(SRC.REGION, '~~')
            OR NVL(TGT.ITEMNAME, '~~') <> NVL(SRC.ITEMNAME, '~~')
            OR NVL(TGT.PRICEPERUNIT, -1) <> NVL(SRC.PRICEPERUNIT, -1)
            OR NVL(TGT.QTY, -1) <> NVL(SRC.QTY, -1)
            OR NVL(TGT.TOTALAMOUNT, -1) <> NVL(SRC.TOTALAMOUNT, -1)
        )
    THEN UPDATE
        SET TGT.NAME = SRC.NAME,
            TGT.EMAILID = SRC.EMAILID,
            TGT.REGION = SRC.REGION,
            TGT.ITEMNAME = SRC.ITEMNAME,
            TGT.PRICEPERUNIT = SRC.PRICEPERUNIT,
            TGT.QTY = SRC.QTY,
            TGT.TOTALAMOUNT = SRC.TOTALAMOUNT,
            TGT.ORDER_DATE = SRC.ORDER_DATE,
            TGT.STARTDATE = SRC.STARTDATE,
            TGT.ENDDATE = SRC.ENDDATE,
            TGT.ISACTIVE = SRC.ISACTIVE,
            TGT.LOAD_TIMESTAMP = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (ORDERID, CUSTID, NAME, EMAILID, REGION, ITEMNAME, PRICEPERUNIT, QTY, TOTALAMOUNT, ORDER_DATE, STARTDATE, ENDDATE, ISACTIVE, LOAD_TIMESTAMP)
        VALUES (SRC.ORDERID, SRC.CUSTID, SRC.NAME, SRC.EMAILID, SRC.REGION, SRC.ITEMNAME, SRC.PRICEPERUNIT, SRC.QTY, SRC.TOTALAMOUNT, SRC.ORDER_DATE, SRC.STARTDATE, SRC.ENDDATE, SRC.ISACTIVE, CURRENT_TIMESTAMP());

    -- Mark records in ordersummary as inactive where customer data changed (SCD2 behavior)
    UPDATE gen_ai_poc_snowflakecoe.sdlc_wizard.ORDERSUMMARY AS OS
    SET OS.ISACTIVE = 'N',
        OS.ENDDATE = CURRENT_DATE()
    WHERE OS.ISACTIVE = 'Y'
      AND EXISTS (
          SELECT 1
          FROM gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMER_SCD2 AS CS
          WHERE CS.CUSTID = OS.CUSTID
            AND CS.IS_CURRENT = FALSE
            AND CS.EFFECTIVE_TO >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
      )
      AND NOT EXISTS (
          SELECT 1
          FROM gen_ai_poc_snowflakecoe.sdlc_wizard."order" AS O
          WHERE O.ORDERID = OS.ORDERID
            AND O.ISACTIVE = 'Y'
      );

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'ORDERSUMMARY loaded and updated successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '09_load_ordersummary')::VARCHAR;
END;