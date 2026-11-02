-- =====================================================================
-- sp_course_roster_report
-- Lists the students enrolled in a course for a semester.
-- Concepts : EXPLICIT CURSOR with parameters used in a CURSOR FOR LOOP,
--            %ROWTYPE record for the course, function calls
-- Errors   : -20451 course does not exist
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_course_roster_report (
  p_course_id IN courses.course_id%TYPE,
  p_semester  IN enrollments.semester%TYPE
)
IS
  v_course  courses%ROWTYPE;
  v_count   PLS_INTEGER := 0;

  CURSOR c_roster (cp_course_id courses.course_id%TYPE,
                   cp_semester  enrollments.semester%TYPE) IS
    SELECT s.student_id,
           s.first_name || ' ' || s.last_name AS full_name,
           e.marks,
           e.grade
      FROM enrollments e
      JOIN students s ON s.student_id = e.student_id
     WHERE e.course_id = cp_course_id
       AND e.semester  = cp_semester
     ORDER BY s.last_name, s.first_name;
BEGIN
  BEGIN
    SELECT * INTO v_course FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20451, 'Course ' || p_course_id || ' does not exist');
  END;

  DBMS_OUTPUT.PUT_LINE('=== ROSTER: ' || v_course.course_code || ' - ' || v_course.title
    || ' (' || p_semester || ') ===');

  -- Cursor FOR loop: OPEN, FETCH and CLOSE are done implicitly
  FOR rec IN c_roster(p_course_id, p_semester) LOOP
    v_count := v_count + 1;
    DBMS_OUTPUT.PUT_LINE(LPAD(v_count, 3) || '. ' || RPAD(rec.student_id, 6)
      || RPAD(rec.full_name, 28)
      || 'marks=' || RPAD(NVL(TO_CHAR(rec.marks), '-'), 7)
      || 'grade=' || NVL(rec.grade, '-'));
  END LOOP;

  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('(no students enrolled)');
  END IF;

  DBMS_OUTPUT.PUT_LINE('Enrolled: ' || v_count || ' | Capacity: ' || v_course.max_capacity
    || ' | Seats left: ' || fn_course_seats_available(p_course_id, p_semester));

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_course_roster_report', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_course_roster_report;
/
SHOW ERRORS
