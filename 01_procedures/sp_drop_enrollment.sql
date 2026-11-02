-- =====================================================================
-- sp_drop_enrollment
-- Withdraws a student from a course. Only UNGRADED enrollments can be
-- dropped; graded ones are part of the academic record.
-- Concepts : implicit cursor on DELETE - SQL%ROWCOUNT, SQL%NOTFOUND,
--            user-defined exceptions, OUT parameter
-- Errors   : -20301 no such enrollment
--            -20302 enrollment already graded - cannot be dropped
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_drop_enrollment (
  p_student_id   IN  enrollments.student_id%TYPE,
  p_course_id    IN  enrollments.course_id%TYPE,
  p_semester     IN  enrollments.semester%TYPE,
  p_rows_deleted OUT PLS_INTEGER
)
IS
  e_not_found     EXCEPTION;       -- user-defined
  e_already_graded EXCEPTION;      -- user-defined
  v_graded_count  PLS_INTEGER;
BEGIN
  DELETE FROM enrollments
   WHERE student_id = p_student_id
     AND course_id  = p_course_id
     AND semester   = p_semester
     AND marks IS NULL;

  p_rows_deleted := SQL%ROWCOUNT;

  IF SQL%NOTFOUND THEN
    -- Nothing deleted: find out WHY so the error message is accurate
    SELECT COUNT(*)
      INTO v_graded_count
      FROM enrollments
     WHERE student_id = p_student_id
       AND course_id  = p_course_id
       AND semester   = p_semester;

    IF v_graded_count > 0 THEN
      RAISE e_already_graded;
    ELSE
      RAISE e_not_found;
    END IF;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Rows deleted (SQL%ROWCOUNT): ' || p_rows_deleted
    || ' | student ' || p_student_id || ' dropped course ' || p_course_id);

EXCEPTION
  WHEN e_already_graded THEN
    RAISE_APPLICATION_ERROR(-20302,
      'Enrollment of student ' || p_student_id || ' in course ' || p_course_id
      || ' is already graded and cannot be dropped');
  WHEN e_not_found THEN
    RAISE_APPLICATION_ERROR(-20301,
      'No enrollment found for student ' || p_student_id || ', course '
      || p_course_id || ', semester ' || p_semester);
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_drop_enrollment', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_drop_enrollment;
/
SHOW ERRORS
