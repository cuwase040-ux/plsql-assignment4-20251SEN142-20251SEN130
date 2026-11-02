-- =====================================================================
-- fn_student_full_name
-- Returns 'First Last' for a student id.
-- Demonstrates a %ROWTYPE record (the whole students row is fetched
-- into one record variable).
-- Errors : -20061  student does not exist
-- Usage  : SELECT fn_student_full_name(1001) FROM dual;
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_student_full_name (
  p_student_id IN students.student_id%TYPE
) RETURN VARCHAR2
IS
  v_student students%ROWTYPE;      -- %ROWTYPE record
BEGIN
  SELECT *
    INTO v_student
    FROM students
   WHERE student_id = p_student_id;

  RETURN v_student.first_name || ' ' || v_student.last_name;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20061, 'Student ' || p_student_id || ' does not exist');
END fn_student_full_name;
/
SHOW ERRORS
