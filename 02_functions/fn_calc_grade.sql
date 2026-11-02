-- =====================================================================
-- fn_calc_grade
-- Converts numeric marks (0-100) into a letter grade.
-- Errors : -20010  marks NULL or outside 0..100
-- Note   : The function RAISES on invalid input instead of returning a
--          default grade, so callers never get a misleading result.
-- Usage  : SELECT fn_calc_grade(85) FROM dual;
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_calc_grade (
  p_marks IN NUMBER
) RETURN VARCHAR2
DETERMINISTIC
IS
BEGIN
  IF p_marks IS NULL OR p_marks < 0 OR p_marks > 100 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'Invalid marks: must be between 0 and 100 (received '
      || NVL(TO_CHAR(p_marks), 'NULL') || ')');
  END IF;

  RETURN CASE
           WHEN p_marks >= 90 THEN 'A'
           WHEN p_marks >= 80 THEN 'B'
           WHEN p_marks >= 70 THEN 'C'
           WHEN p_marks >= 60 THEN 'D'
           ELSE 'F'
         END;
END fn_calc_grade;
/
SHOW ERRORS
