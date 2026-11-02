-- =====================================================================
-- fn_find_student_by_lastname
-- Returns the student_id for a last name (case-insensitive).
-- Demonstrates the predefined exceptions NO_DATA_FOUND and TOO_MANY_ROWS,
-- each translated to a meaningful application error.
-- Errors : -20031  no student has this last name
--          -20032  several students share this last name (ambiguous)
-- Usage  : SELECT fn_find_student_by_lastname('Uwase') FROM dual;
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_find_student_by_lastname (
  p_last_name IN students.last_name%TYPE
) RETURN NUMBER
IS
  v_student_id students.student_id%TYPE;
BEGIN
  SELECT student_id
    INTO v_student_id
    FROM students
   WHERE UPPER(last_name) = UPPER(TRIM(p_last_name));

  RETURN v_student_id;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20031,
      'No student found with last name ''' || p_last_name || '''');
  WHEN TOO_MANY_ROWS THEN
    RAISE_APPLICATION_ERROR(-20032,
      'More than one student has last name ''' || p_last_name
      || '''; search by student id instead');
END fn_find_student_by_lastname;
/
SHOW ERRORS
