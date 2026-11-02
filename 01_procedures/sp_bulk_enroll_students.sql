-- =====================================================================
-- sp_bulk_enroll_students
-- Enrolls a LIST of students (nested-table parameter) in one course with a
-- single FORALL INSERT.
-- Concepts : collection as IN parameter, FORALL INSERT ... SAVE EXCEPTIONS,
--            SQL%BULK_EXCEPTIONS, ORA-24381, partial success
-- Errors   : -20701 list is NULL or empty
--            -20702 course does not exist
--            -20703 not enough seats for the whole list
-- Behaviour: unknown student ids (ORA-02291) and duplicates (ORA-00001) do
--            not stop the batch; each one is reported, logged and counted
--            in p_failed while the valid ones are inserted.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_bulk_enroll_students (
  p_course_id   IN  courses.course_id%TYPE,
  p_semester    IN  enrollments.semester%TYPE,
  p_student_ids IN  t_num_tab,
  p_enrolled    OUT PLS_INTEGER,
  p_failed      OUT PLS_INTEGER
)
IS
  e_bulk_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);

  v_course    courses%ROWTYPE;
  v_seats     NUMBER;
  v_err_count PLS_INTEGER;
  v_err_idx   PLS_INTEGER;
  v_err_code  PLS_INTEGER;
BEGIN
  p_enrolled := 0;
  p_failed   := 0;

  IF p_student_ids IS NULL OR p_student_ids.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20701, 'The list of student ids is empty');
  END IF;

  BEGIN
    SELECT * INTO v_course FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20702, 'Course ' || p_course_id || ' does not exist');
  END;

  v_seats := fn_course_seats_available(p_course_id, p_semester);
  IF p_student_ids.COUNT > v_seats THEN
    RAISE_APPLICATION_ERROR(-20703,
      'Only ' || v_seats || ' seat(s) left in ' || v_course.course_code
      || ' but ' || p_student_ids.COUNT || ' student(s) requested');
  END IF;

  FORALL i IN 1 .. p_student_ids.COUNT SAVE EXCEPTIONS
    INSERT INTO enrollments (enrollment_id, student_id, course_id, semester)
    VALUES (seq_enrollment.NEXTVAL, p_student_ids(i), p_course_id, p_semester);

  p_enrolled := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('Bulk enrolled ' || p_enrolled || ' student(s) in ' || v_course.course_code);

EXCEPTION
  WHEN e_bulk_errors THEN
    p_enrolled  := SQL%ROWCOUNT;
    v_err_count := SQL%BULK_EXCEPTIONS.COUNT;
    p_failed    := v_err_count;

    FOR j IN 1 .. v_err_count LOOP
      v_err_idx  := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
      v_err_code := SQL%BULK_EXCEPTIONS(j).ERROR_CODE;
      DBMS_OUTPUT.PUT_LINE('Bulk error: student ' || p_student_ids(v_err_idx)
        || ' not enrolled -> ' || SQLERRM(-v_err_code));
      sp_log_error('sp_bulk_enroll_students', -v_err_code,
        'Student ' || p_student_ids(v_err_idx) || ', course ' || p_course_id
        || ': ' || SQLERRM(-v_err_code));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Enrolled ' || p_enrolled || ', failed ' || p_failed);
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_bulk_enroll_students', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_bulk_enroll_students;
/
SHOW ERRORS
