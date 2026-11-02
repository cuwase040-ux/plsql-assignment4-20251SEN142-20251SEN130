-- =====================================================================
-- sp_record_marks
-- Records (or corrects) the marks of one enrollment, derives the letter
-- grade, and writes an audit row. Returns the grade (OUT parameter).
-- Concepts : %ROWTYPE record, SELECT ... FOR UPDATE, implicit cursor
--            SQL%FOUND and SQL%ROWCOUNT on UPDATE, user-defined
--            exception, function call, audit insert
-- Errors   : -20010 marks invalid (raised by fn_calc_grade, passed through)
--            -20201 enrollment does not exist
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_record_marks (
  p_enrollment_id IN  enrollments.enrollment_id%TYPE,
  p_marks         IN  enrollments.marks%TYPE,
  p_grade         OUT enrollments.grade%TYPE
)
IS
  e_enrollment_missing EXCEPTION;     -- user-defined

  v_old       enrollments%ROWTYPE;    -- record holding the row BEFORE the change
  v_rows_upd  PLS_INTEGER;
BEGIN
  -- Validates the marks; raises -20010 if out of range
  p_grade := fn_calc_grade(p_marks);

  -- Lock the row and keep its old values for the audit trail
  BEGIN
    SELECT *
      INTO v_old
      FROM enrollments
     WHERE enrollment_id = p_enrollment_id
       FOR UPDATE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE e_enrollment_missing;
  END;

  UPDATE enrollments
     SET marks = p_marks,
         grade = p_grade
   WHERE enrollment_id = p_enrollment_id;

  -- Implicit cursor attributes of the UPDATE
  IF SQL%FOUND THEN
    v_rows_upd := SQL%ROWCOUNT;

    INSERT INTO grade_audit
      (audit_id, enrollment_id, old_marks, new_marks, old_grade, new_grade)
    VALUES
      (seq_audit.NEXTVAL, p_enrollment_id, v_old.marks, p_marks, v_old.grade, p_grade);

    DBMS_OUTPUT.PUT_LINE('Rows updated (SQL%ROWCOUNT): ' || v_rows_upd
      || ' | marks ' || NVL(TO_CHAR(v_old.marks), 'none') || ' -> ' || p_marks
      || ' | grade ' || NVL(v_old.grade, '-') || ' -> ' || p_grade);
  END IF;

EXCEPTION
  WHEN e_enrollment_missing THEN
    RAISE_APPLICATION_ERROR(-20201, 'Enrollment ' || p_enrollment_id || ' does not exist');
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_record_marks', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_record_marks;
/
SHOW ERRORS
