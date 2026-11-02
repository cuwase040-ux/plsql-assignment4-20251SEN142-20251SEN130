-- =====================================================================
-- sp_register_student
-- Registers a new student and returns the generated id (OUT parameter).
-- Concepts : %ROWTYPE record, record-based INSERT, implicit cursor
--            SQL%ROWCOUNT, user-defined exception, mapped FK error,
--            predefined exception DUP_VAL_ON_INDEX, RAISE_APPLICATION_ERROR
-- Errors   : -20001 department does not exist (ORA-02291 mapped)
--            -20002 e-mail already registered (DUP_VAL_ON_INDEX)
--            -20003 first or last name is blank (user-defined exception)
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_register_student (
  p_first_name IN  students.first_name%TYPE,
  p_last_name  IN  students.last_name%TYPE,
  p_email      IN  students.email%TYPE,
  p_dept_id    IN  students.dept_id%TYPE,
  p_student_id OUT students.student_id%TYPE
)
IS
  e_invalid_name   EXCEPTION;                       -- user-defined
  e_dept_not_found EXCEPTION;                       -- user-defined, tied to ORA-02291
  PRAGMA EXCEPTION_INIT(e_dept_not_found, -2291);   -- parent key not found

  v_student students%ROWTYPE;                       -- %ROWTYPE record
BEGIN
  IF TRIM(p_first_name) IS NULL OR TRIM(p_last_name) IS NULL THEN
    RAISE e_invalid_name;
  END IF;

  -- Build the record field by field, then insert the whole record
  v_student.student_id := seq_student.NEXTVAL;
  v_student.first_name := TRIM(p_first_name);
  v_student.last_name  := TRIM(p_last_name);
  v_student.email      := LOWER(TRIM(p_email));
  v_student.dept_id    := p_dept_id;
  v_student.enrol_date := SYSDATE;
  v_student.status     := 'ACTIVE';
  v_student.gpa        := NULL;

  INSERT INTO students VALUES v_student;

  -- Implicit cursor attribute right after the INSERT
  DBMS_OUTPUT.PUT_LINE('Rows inserted (SQL%ROWCOUNT): ' || SQL%ROWCOUNT);

  p_student_id := v_student.student_id;
  DBMS_OUTPUT.PUT_LINE('Student registered with id ' || p_student_id);

EXCEPTION
  WHEN e_invalid_name THEN
    RAISE_APPLICATION_ERROR(-20003, 'First name and last name are required');
  WHEN e_dept_not_found THEN
    RAISE_APPLICATION_ERROR(-20001, 'Department ' || p_dept_id || ' does not exist');
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20002, 'E-mail ''' || p_email || ''' is already registered');
  WHEN OTHERS THEN
    -- Unexpected error: log it, then re-raise (never swallowed)
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_register_student', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_register_student;
/
SHOW ERRORS
