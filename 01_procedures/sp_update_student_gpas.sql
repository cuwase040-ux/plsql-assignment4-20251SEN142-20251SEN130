-- =====================================================================
-- sp_update_student_gpas
-- Recalculates the stored GPA of every student.
-- Concepts : explicit cursor + BULK COLLECT ... LIMIT (batch processing),
--            associative arrays, FORALL UPDATE, function call per student,
--            handling of the function's -20021 error (EXCEPTION_INIT)
-- Behaviour: students with no graded course are SKIPPED and COUNTED
--            (p_skipped); their GPA is not invented. Any other error is
--            logged and re-raised.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_update_student_gpas (
  p_updated OUT PLS_INTEGER,
  p_skipped OUT PLS_INTEGER
)
IS
  c_batch_size CONSTANT PLS_INTEGER := 100;

  TYPE t_id_arr  IS TABLE OF students.student_id%TYPE INDEX BY PLS_INTEGER;
  TYPE t_gpa_arr IS TABLE OF students.gpa%TYPE        INDEX BY PLS_INTEGER;

  v_batch   t_id_arr;       -- ids fetched in the current batch
  v_ok_ids  t_id_arr;       -- ids whose GPA could be computed
  v_ok_gpas t_gpa_arr;      -- matching GPA values
  v_n       PLS_INTEGER;
  v_gpa     NUMBER;

  e_no_graded EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_no_graded, -20021);
  e_bulk_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);

  v_err_count PLS_INTEGER;

  CURSOR c_students IS
    SELECT student_id FROM students ORDER BY student_id;
BEGIN
  p_updated := 0;
  p_skipped := 0;

  OPEN c_students;
  LOOP
    -- Fetch up to 100 ids per round trip (keeps PGA memory bounded)
    FETCH c_students BULK COLLECT INTO v_batch LIMIT c_batch_size;
    EXIT WHEN v_batch.COUNT = 0;

    v_ok_ids.DELETE;
    v_ok_gpas.DELETE;
    v_n := 0;

    FOR i IN 1 .. v_batch.COUNT LOOP
      BEGIN
        v_gpa := fn_student_gpa(v_batch(i));
        v_n := v_n + 1;
        v_ok_ids(v_n)  := v_batch(i);
        v_ok_gpas(v_n) := v_gpa;
      EXCEPTION
        WHEN e_no_graded THEN
          p_skipped := p_skipped + 1;     -- counted, reported to the caller
      END;
    END LOOP;

    IF v_n > 0 THEN
      FORALL i IN 1 .. v_n SAVE EXCEPTIONS
        UPDATE students
           SET gpa = v_ok_gpas(i)
         WHERE student_id = v_ok_ids(i);
      p_updated := p_updated + SQL%ROWCOUNT;
    END IF;
  END LOOP;
  CLOSE c_students;

  DBMS_OUTPUT.PUT_LINE('GPA updated for ' || p_updated || ' student(s); skipped '
    || p_skipped || ' (no graded courses)');

EXCEPTION
  WHEN e_bulk_errors THEN
    v_err_count := SQL%BULK_EXCEPTIONS.COUNT;
    FOR j IN 1 .. v_err_count LOOP
      sp_log_error('sp_update_student_gpas', -SQL%BULK_EXCEPTIONS(j).ERROR_CODE,
        'Student ' || v_ok_ids(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX) || ': '
        || SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
    END LOOP;
    IF c_students%ISOPEN THEN CLOSE c_students; END IF;
    RAISE;
  WHEN OTHERS THEN
    IF c_students%ISOPEN THEN CLOSE c_students; END IF;
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_update_student_gpas', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_update_student_gpas;
/
SHOW ERRORS
