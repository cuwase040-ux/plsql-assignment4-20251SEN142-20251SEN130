-- =====================================================================
-- fn_course_seats_available
-- Remaining seats of a course in a semester = capacity - enrolled.
-- A result of 0 means the course is full.
-- Errors : -20040  course does not exist
-- Usage  : SELECT fn_course_seats_available(101, '2026-A') FROM dual;
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_course_seats_available (
  p_course_id IN courses.course_id%TYPE,
  p_semester  IN enrollments.semester%TYPE
) RETURN NUMBER
IS
  v_capacity courses.max_capacity%TYPE;
  v_taken    NUMBER;
BEGIN
  SELECT max_capacity
    INTO v_capacity
    FROM courses
   WHERE course_id = p_course_id;

  SELECT COUNT(*)
    INTO v_taken
    FROM enrollments
   WHERE course_id = p_course_id
     AND semester  = p_semester;

  RETURN v_capacity - v_taken;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20040, 'Course ' || p_course_id || ' does not exist');
END fn_course_seats_available;
/
SHOW ERRORS
