-- =====================================================================
-- sp_enroll_student
-- Enrolls ONE student in ONE course for a semester; returns the new
-- enrollment id (OUT parameter).
-- Concepts : %ROWTYPE records, SELECT ... INTO (NO_DATA_FOUND),
--            INSERT ... RETURNING INTO, implicit cursor SQL%ROWCOUNT,
--            user-defined exceptions, DUP_VAL_ON_INDEX, function call
-- Errors   : -20101 student not found
--            -20102 course not found
--            -20103 student is not ACTIVE
--            -20104 course is full
--            -20105 student already enrolled in this course/semester
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_enroll_student (
  p_student_id    IN  students.student_id%TYPE,
  p_course_id     IN  courses.course_id%TYPE,
  p_semester      IN  enrollments.semester%TYPE,
  p_enrollment_id OUT enrollments.enrollment_id%TYPE
)
IS
  e_student_inactive EXCEPTION;     -- user-defined
  e_course_full      EXCEPTION;     -- user-defined

  v_student students%ROWTYPE;       -- %ROWTYPE records
  v_course  courses%ROWTYPE;
  v_seats   NUMBER;
BEGIN
  -- 1) Student must exist
  BEGIN
    SELECT * INTO v_student FROM students WHERE student_id = p_student_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Student ' || p_student_id || ' does not exist');
  END;

  -- 2) Course must exist
  BEGIN
    SELECT * INTO v_course FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20102, 'Course ' || p_course_id || ' does not exist');
  END;

  -- 3) Business rules
  IF v_student.status <> 'ACTIVE' THEN
    RAISE e_student_inactive;
  END IF;

  v_seats := fn_course_seats_available(p_course_id, p_semester);
  IF v_seats <= 0 THEN
    RAISE e_course_full;
  END IF;

  -- 4) Insert and capture the generated key
  INSERT INTO enrollments (enrollment_id, student_id, course_id, semester)
  VALUES (seq_enrollment.NEXTVAL, p_student_id, p_course_id, p_semester)
  RETURNING enrollment_id INTO p_enrollment_id;

  DBMS_OUTPUT.PUT_LINE('Rows inserted (SQL%ROWCOUNT): ' || SQL%ROWCOUNT
    || ' | ' || v_student.first_name || ' ' || v_student.last_name
    || ' enrolled in ' || v_course.course_code
    || ' (enrollment id ' || p_enrollment_id || ')');

EXCEPTION
  WHEN e_student_inactive THEN
    RAISE_APPLICATION_ERROR(-20103,
      'Student ' || p_student_id || ' has status ' || v_student.status || ' and cannot enroll');
  WHEN e_course_full THEN
    RAISE_APPLICATION_ERROR(-20104,
      'Course ' || v_course.course_code || ' is full for semester ' || p_semester);
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20105,
      'Student ' || p_student_id || ' is already enrolled in course '
      || p_course_id || ' for ' || p_semester);
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_enroll_student', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_enroll_student;
/
SHOW ERRORS
