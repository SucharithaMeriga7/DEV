BEGIN
    -- Truncate and reload aggregated spend data
    TRUNCATE TABLE IF EXISTS gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMERAGGREGATESPEND;

    INSERT INTO gen_ai_poc_snowflakecoe.sdlc_wizard.CUSTOMERAGGREGATESPEND (
        NAME,
        ORDER_DATE,
        TOTAL_SPEND,
        LOAD_TIMESTAMP
    )
    SELECT
        NAME,
        ORDER_DATE,
        SUM(TOTALAMOUNT) AS TOTAL_SPEND,
        CURRENT_TIMESTAMP() AS LOAD_TIMESTAMP
    FROM gen_ai_poc_snowflakecoe.sdlc_wizard.ORDERSUMMARY
    WHERE NAME IS NOT NULL
      AND ORDER_DATE IS NOT NULL
    GROUP BY NAME, ORDER_DATE
    ORDER BY NAME, ORDER_DATE;

    RETURN OBJECT_CONSTRUCT('status', 'SUCCESS', 'message', 'CUSTOMERAGGREGATESPEND loaded successfully')::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT('error', SQLERRM, 'step', '11_load_customeraggregatespend')::VARCHAR;
END;