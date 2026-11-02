-- =====================================================================
-- sp_course_grade_distribution
-- Counts how many students got each letter grade in a course.
-- Concepts : ASSOCIATIVE ARRAY indexed by VARCHAR2 (grade -> count),
--            VARRAY (fixed list of valid grades), cursor FOR loop
--            over an inline query
-- Errors   : -20501 course does not exist
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_course_grade_distribution (
  p_course_id IN courses.course_id%TYPE,
  p_semester  IN enrollments.semester%TYPE
)
IS
  -- Associative array: key = grade letter, value = number of students
  TYPE t_count_map IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(1);
  v_counts t_count_map;

  -- VARRAY (schema type): the five valid grades, in display order
  v_labels t_grade_labels := t_grade_labels('A', 'B', 'C', 'D', 'F');

  v_title  courses.title%TYPE;
  v_total  PLS_INTEGER := 0;
BEGIN
  BEGIN
    SELECT title INTO v_title FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20501, 'Course ' || p_course_id || ' does not exist');
  END;

  -- Initialise every bucket to 0
  FOR i IN 1 .. v_labels.COUNT LOOP
    v_counts(v_labels(i)) := 0;
  END LOOP;

  -- Count graded enrollments (cursor FOR loop over an inline query)
  FOR rec IN (SELECT grade
                FROM enrollments
               WHERE course_id = p_course_id
                 AND semester  = p_semester
                 AND grade IS NOT NULL) LOOP
    v_counts(rec.grade) := v_counts(rec.grade) + 1;
    v_total := v_total + 1;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('=== GRADE DISTRIBUTION: ' || v_title || ' (' || p_semester || ') ===');
  FOR i IN 1 .. v_labels.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(v_labels(i) || ' : ' || LPAD(v_counts(v_labels(i)), 3) || '  '
      || RPAD('*', v_counts(v_labels(i)), '*'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Graded students: ' || v_total);

  IF v_total = 0 THEN
    DBMS_OUTPUT.PUT_LINE('(no grades recorded yet for this course/semester)');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE NOT BETWEEN -20999 AND -20000 THEN
      sp_log_error('sp_course_grade_distribution', SQLCODE, SQLERRM);
    END IF;
    RAISE;
END sp_course_grade_distribution;
/
SHOW ERRORS
