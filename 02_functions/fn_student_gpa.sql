-- =====================================================================
-- fn_student_gpa
-- Credit-weighted GPA on a 4.0 scale (A=4, B=3, C=2, D=1, F=0).
-- Uses an EXPLICIT CURSOR (cursor FOR loop) over the student's graded
-- enrollments.
-- Errors : -20020  student does not exist          (NO_DATA_FOUND mapped)
--          -20021  student has no graded enrollments (GPA undefined, so we
--                  raise instead of returning a misleading 0)
-- Usage  : SELECT fn_student_gpa(1001) FROM dual;
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_student_gpa (
  p_student_id IN students.student_id%TYPE
) RETURN NUMBER
IS
  v_dummy    students.student_id%TYPE;
  v_points   NUMBER := 0;     -- sum(grade_points * credits)
  v_credits  NUMBER := 0;     -- sum(credits)
  v_gp       NUMBER;          -- grade points of one course

  CURSOR c_graded IS
    SELECT e.grade, c.credits
      FROM enrollments e
      JOIN courses c ON c.course_id = e.course_id
     WHERE e.student_id = p_student_id
       AND e.grade IS NOT NULL;
BEGIN
  -- Predefined exception NO_DATA_FOUND is raised here for unknown students
  SELECT student_id INTO v_dummy
    FROM students
   WHERE student_id = p_student_id;

  FOR rec IN c_graded LOOP
    v_gp := CASE rec.grade
              WHEN 'A' THEN 4
              WHEN 'B' THEN 3
              WHEN 'C' THEN 2
              WHEN 'D' THEN 1
              ELSE 0
            END;
    v_points  := v_points  + v_gp * rec.credits;
    v_credits := v_credits + rec.credits;
  END LOOP;

  IF v_credits = 0 THEN
    RAISE_APPLICATION_ERROR(-20021,
      'Student ' || p_student_id || ' has no graded enrollments; GPA cannot be computed');
  END IF;

  RETURN ROUND(v_points / v_credits, 2);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20020, 'Student ' || p_student_id || ' does not exist');
END fn_student_gpa;
/
SHOW ERRORS
