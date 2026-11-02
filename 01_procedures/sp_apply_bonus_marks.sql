-- =====================================================================
-- sp_apply_bonus_marks
-- Adds (or subtracts) bonus marks for every graded student of a course and
-- recalculates their letter grade, all in bulk.
-- Concepts : BULK COLLECT into several nested tables, FORALL UPDATE with
--            SAVE EXCEPTIONS, SQL%BULK_EXCEPTIONS, ORA-24381, and a
--            REAL bulk-DML failure: a student whose marks would exceed 100
--            violates CHECK constraint ck_enr_marks (ORA-02290). That row is
--            logged and reported while all other rows are still updated.
-- Errors   : -20601 bonus is NULL, zero, or outside -100..100
--            -20602 course does not exist
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_apply_bonus_marks (
  p_course_id IN  courses.course_id%TYPE,
  p_semester  IN  enrollments.semester%TYPE,
  p_bonus     IN  NUMBER,
  p_updated   OUT PLS_INTEGER,
  p_failed    OUT PLS_INTEGER
)
IS
  TYPE t_id_tab    IS TABLE OF enrollments.enrollment_id%TYPE;
  TYPE t_marks_tab IS TABLE OF enrollments.marks%TYPE;
  TYPE t_grade_tab IS TABLE OF enrollments.grade%TYPE;

  v_ids        t_id_tab;
  v_old_marks  t_marks_tab;
  v_new_marks  t_marks_tab := t_marks_tab();
  v_new_grades t_grade_tab := t_grade_tab();

  e_bulk_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);

  v_title     courses.title%TYPE;
  v_err_count PLS_INTEGER;
  v_err_idx   PLS_INTEGER;
  v_err_code  PLS_INTEGER;
BEGIN
  p_updated := 0;
  p_failed  := 0;

  IF p_bonus IS NULL OR p_bonus = 0 OR ABS(p_bonus) > 100 THEN
    RAISE_APPLICATION_ERROR(-20601,
      'Bonus must be non-zero and between -100 and 100 (received '
      || NVL(TO_CHAR(p_bonus), 'NULL') || ')');
  END IF;

  BEGIN
    SELECT title INTO v_title FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20602, 'Course ' || p_course_id || ' does not exist');
  END;

  -- Bulk fetch into two collections at once
  SELECT enrollment_id, marks
    BULK COLLECT INTO v_ids, v_old_marks
    FROM enrollments
   WHERE course_id = p_course_id
     AND semester  = p_semester
     AND marks IS NOT NULL;

  IF v_ids.COUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No marked enrollments in ' || v_title || ' (' || p_semester || ')');
    RETURN;
  END IF;

  v_new_marks.EXTEND(v_ids.COUNT);
  v_new_grades.EXTEND(v_ids.COUNT);

  FOR i IN 1 .. v_ids.COUNT LOOP
    v_new_marks(i) := v_old_marks(i) + p_bonus;
    -- Grade is derived from the value clamped to 0..100. The marks column
    -- itself keeps the raw value, so an overflow (>100) is rejected by the
    -- CHECK constraint inside FORALL and reported through SAVE EXCEPTIONS.
    v_new_grades(i) := fn_calc_grade(LEAST(GREATEST(v_new_marks(i), 0), 100));
  END LOOP;

  FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
    UPDATE enrollments
       SET marks = v_new_marks(i),
           grade = v_new_grades(i)
     WHERE enrollment_id = v_ids(i);

  p_updated := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('Bonus ' || p_bonus || ' applied to ' || p_updated
    || ' enrollment(s) in ' || v_title);

EXCEPTION
  WHEN e_bulk_errors THEN
    p_updated   := SQL%ROWCOUNT;
    v_err_count := SQL%BULK_EXCEPTIONS.COUNT;
    p_failed    := v_err_count;

    FOR j IN 1 .. v_err_count LOOP
      v_err_idx  := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
      v_err_code := SQL%BULK_EXCEPTIONS(j).ERROR_CODE;
      DBMS_OUTPUT.PUT_LINE('Bulk error: enrollment ' || v_ids(v_err_idx)
        || ' (marks ' || v_old_marks(v_err_idx) || ' + ' || p_bonus || ' = '
        || v_new_marks(v_err_idx) || ') -> ' || SQLERRM(-v_err_code));
      sp_log_error('sp_apply_bonus_marks', -v_err_code,
        'Enrollment ' || v_ids(v_err_idx) || ': ' || SQLERRM(-v_err_code));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Updated ' || p_updated || ', failed ' || p_failed);
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_apply_bonus_marks', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_apply_bonus_marks;
/
SHOW ERRORS
