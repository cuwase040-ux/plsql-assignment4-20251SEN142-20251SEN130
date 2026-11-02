-- =====================================================================
-- sp_perf_compare
-- Measures INSERT of N rows done (a) row-by-row in a FOR loop and
-- (b) in bulk with FORALL, to show why bulk processing is faster.
--
-- WHY FORALL IS FASTER
--   A plain loop sends one INSERT per iteration from the PL/SQL engine to
--   the SQL engine: N context switches, N statement executions.
--   FORALL sends the whole collection in ONE bulk bind: 1 context switch.
--
-- Errors   : -20801 p_rows is NULL or outside 1..1,000,000
-- Note     : The procedure empties and refills the scratch table PERF_TEST
--            and does NOT commit; the caller decides (the tests ROLLBACK).
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_perf_compare (
  p_rows IN PLS_INTEGER DEFAULT 10000
)
IS
  TYPE t_id_tab  IS TABLE OF perf_test.id%TYPE;
  TYPE t_txt_tab IS TABLE OF perf_test.payload%TYPE;
  v_ids  t_id_tab  := t_id_tab();
  v_txts t_txt_tab := t_txt_tab();

  v_start     PLS_INTEGER;
  v_row_cs    PLS_INTEGER;     -- centiseconds, row-by-row
  v_bulk_cs   PLS_INTEGER;     -- centiseconds, FORALL
BEGIN
  IF p_rows IS NULL OR p_rows < 1 OR p_rows > 1000000 THEN
    RAISE_APPLICATION_ERROR(-20801,
      'p_rows must be between 1 and 1000000 (received '
      || NVL(TO_CHAR(p_rows), 'NULL') || ')');
  END IF;

  -- Prepare the data once, in memory
  v_ids.EXTEND(p_rows);
  v_txts.EXTEND(p_rows);
  FOR i IN 1 .. p_rows LOOP
    v_ids(i)  := i;
    v_txts(i) := 'Row payload ' || i;
  END LOOP;

  -- (a) Row-by-row
  DELETE FROM perf_test;
  v_start := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. p_rows LOOP
    INSERT INTO perf_test (id, payload) VALUES (v_ids(i), v_txts(i));
  END LOOP;
  v_row_cs := DBMS_UTILITY.GET_TIME - v_start;

  -- (b) Bulk with FORALL
  DELETE FROM perf_test;
  v_start := DBMS_UTILITY.GET_TIME;
  FORALL i IN 1 .. p_rows
    INSERT INTO perf_test (id, payload) VALUES (v_ids(i), v_txts(i));
  v_bulk_cs := DBMS_UTILITY.GET_TIME - v_start;

  DBMS_OUTPUT.PUT_LINE('Rows inserted           : ' || p_rows);
  DBMS_OUTPUT.PUT_LINE('Row-by-row (FOR loop)   : ' || v_row_cs  * 10 || ' ms');
  DBMS_OUTPUT.PUT_LINE('Bulk (FORALL)           : ' || v_bulk_cs * 10 || ' ms');
  IF v_bulk_cs > 0 THEN
    DBMS_OUTPUT.PUT_LINE('FORALL was ' || ROUND(v_row_cs / v_bulk_cs, 1) || 'x faster');
  ELSE
    DBMS_OUTPUT.PUT_LINE('FORALL finished in under 10 ms (too fast to compute a ratio)');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_perf_compare', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_perf_compare;
/
SHOW ERRORS
