-- =====================================================================
-- sp_bulk_assign_grades
-- Assigns letter grades to every enrollment of a course/semester that has
-- marks but no grade yet.
-- Concepts : BULK COLLECT into a nested table of %ROWTYPE records,
--            associative arrays, FORALL ... SAVE EXCEPTIONS,
--            SQL%BULK_EXCEPTIONS, ORA-24381 handling
-- Errors   : -20551 course does not exist
-- Behaviour: rows that fail inside FORALL are LOGGED and COUNTED
--            (p_failed) - they are never silently ignored; the rows that
--            succeeded stay updated (partial success).
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_bulk_assign_grades (
  p_course_id IN  courses.course_id%TYPE,
  p_semester  IN  enrollments.semester%TYPE,
  p_graded    OUT PLS_INTEGER,
  p_failed    OUT PLS_INTEGER
)
IS
  -- Collection of records (one record per ungraded enrollment)
  TYPE t_enr_tab   IS TABLE OF enrollments%ROWTYPE;
  v_rows t_enr_tab;

  -- Parallel arrays used by FORALL
  TYPE t_id_arr    IS TABLE OF enrollments.enrollment_id%TYPE INDEX BY PLS_INTEGER;
  TYPE t_grade_arr IS TABLE OF enrollments.grade%TYPE         INDEX BY PLS_INTEGER;
  v_ids    t_id_arr;
  v_grades t_grade_arr;

  e_bulk_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);

  v_title     courses.title%TYPE;
  v_err_count PLS_INTEGER;
  v_err_idx   PLS_INTEGER;
  v_err_code  PLS_INTEGER;
BEGIN
  p_graded := 0;
  p_failed := 0;

  BEGIN
    SELECT title INTO v_title FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20551, 'Course ' || p_course_id || ' does not exist');
  END;

  -- ONE round trip fetches every row that needs a grade
  SELECT *
    BULK COLLECT INTO v_rows
    FROM enrollments
   WHERE course_id = p_course_id
     AND semester  = p_semester
     AND marks IS NOT NULL
     AND grade IS NULL;

  IF v_rows.COUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('Nothing to grade for ' || v_title || ' (' || p_semester || ')');
    RETURN;
  END IF;

  -- Compute grades in PL/SQL memory
  FOR i IN 1 .. v_rows.COUNT LOOP
    v_ids(i)    := v_rows(i).enrollment_id;
    v_grades(i) := fn_calc_grade(v_rows(i).marks);
  END LOOP;

  -- ONE bulk-bind UPDATE instead of v_rows.COUNT separate UPDATEs
  FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
    UPDATE enrollments
       SET grade = v_grades(i)
     WHERE enrollment_id = v_ids(i);

  p_graded := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('Graded ' || p_graded || ' enrollment(s) in ' || v_title);

EXCEPTION
  WHEN e_bulk_errors THEN
    p_graded    := SQL%ROWCOUNT;                 -- rows that succeeded
    v_err_count := SQL%BULK_EXCEPTIONS.COUNT;    -- rows that failed
    p_failed    := v_err_count;

    FOR j IN 1 .. v_err_count LOOP
      v_err_idx  := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
      v_err_code := SQL%BULK_EXCEPTIONS(j).ERROR_CODE;
      DBMS_OUTPUT.PUT_LINE('Bulk error: enrollment ' || v_ids(v_err_idx)
        || ' -> ' || SQLERRM(-v_err_code));
      sp_log_error('sp_bulk_assign_grades', -v_err_code,
        'Enrollment ' || v_ids(v_err_idx) || ': ' || SQLERRM(-v_err_code));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Graded ' || p_graded || ', failed ' || p_failed);
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_bulk_assign_grades', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_bulk_assign_grades;
/
SHOW ERRORS
