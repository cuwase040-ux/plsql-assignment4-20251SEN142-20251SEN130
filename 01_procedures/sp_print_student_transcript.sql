-- =====================================================================
-- sp_print_student_transcript
-- Prints a student's transcript and GPA.
-- Concepts : USER-DEFINED RECORD type, %ROWTYPE record, EXPLICIT CURSOR
--            with a parameter processed by OPEN / FETCH / CLOSE,
--            cursor attributes %NOTFOUND, %ROWCOUNT, %ISOPEN,
--            exception mapped with EXCEPTION_INIT
-- Errors   : -20401 student does not exist
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_print_student_transcript (
  p_student_id IN students.student_id%TYPE
)
IS
  -- User-defined record: one transcript line
  TYPE r_transcript_line IS RECORD (
    semester     enrollments.semester%TYPE,
    course_code  courses.course_code%TYPE,
    title        courses.title%TYPE,
    credits      courses.credits%TYPE,
    marks        enrollments.marks%TYPE,
    grade        enrollments.grade%TYPE
  );
  v_line    r_transcript_line;
  v_student students%ROWTYPE;                    -- %ROWTYPE record
  v_gpa     NUMBER;

  e_no_graded EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_no_graded, -20021);    -- raised by fn_student_gpa

  -- Explicit cursor with a parameter
  CURSOR c_lines (cp_student_id students.student_id%TYPE) IS
    SELECT e.semester, c.course_code, c.title, c.credits, e.marks, e.grade
      FROM enrollments e
      JOIN courses c ON c.course_id = e.course_id
     WHERE e.student_id = cp_student_id
     ORDER BY e.semester, c.course_code;
BEGIN
  BEGIN
    SELECT * INTO v_student FROM students WHERE student_id = p_student_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20401, 'Student ' || p_student_id || ' does not exist');
  END;

  DBMS_OUTPUT.PUT_LINE('==================== TRANSCRIPT ====================');
  DBMS_OUTPUT.PUT_LINE('Student : ' || v_student.student_id || ' - '
    || v_student.first_name || ' ' || v_student.last_name
    || ' (' || v_student.status || ')');
  DBMS_OUTPUT.PUT_LINE(RPAD('Semester', 10) || RPAD('Code', 10) || RPAD('Title', 36)
    || RPAD('Cr', 4) || RPAD('Marks', 7) || 'Grade');
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 72, '-'));

  OPEN c_lines(p_student_id);
  LOOP
    FETCH c_lines INTO v_line;
    EXIT WHEN c_lines%NOTFOUND;

    DBMS_OUTPUT.PUT_LINE(RPAD(v_line.semester, 10) || RPAD(v_line.course_code, 10)
      || RPAD(SUBSTR(v_line.title, 1, 34), 36) || RPAD(v_line.credits, 4)
      || RPAD(NVL(TO_CHAR(v_line.marks), '-'), 7) || NVL(v_line.grade, '-'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Courses listed: ' || c_lines%ROWCOUNT);
  CLOSE c_lines;

  -- GPA: the function raises -20021 when nothing is graded; report it honestly
  BEGIN
    v_gpa := fn_student_gpa(p_student_id);
    DBMS_OUTPUT.PUT_LINE('GPA     : ' || TO_CHAR(v_gpa, 'FM0.00'));
  EXCEPTION
    WHEN e_no_graded THEN
      DBMS_OUTPUT.PUT_LINE('GPA     : not available (no graded courses yet)');
  END;
  DBMS_OUTPUT.PUT_LINE('====================================================');

EXCEPTION
  WHEN OTHERS THEN
    IF c_lines%ISOPEN THEN
      CLOSE c_lines;                              -- never leak a cursor
    END IF;
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_print_student_transcript', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_print_student_transcript;
/
SHOW ERRORS
