-- =====================================================================
-- fn_top_students
-- Returns the ids of the N students with the highest GPA as a NESTED TABLE
-- (collection) filled with BULK COLLECT. Because t_num_tab is a schema-level
-- type, the result can be queried from SQL with TABLE(...).
-- Errors : -20050  p_n is NULL or < 1
--          -20051  no GPA has been computed yet
--                  (run sp_update_student_gpas first)
-- Usage  : SELECT s.student_id, s.first_name, s.gpa
--            FROM TABLE(fn_top_students(3)) t
--            JOIN students s ON s.student_id = t.COLUMN_VALUE
--           ORDER BY s.gpa DESC;
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_top_students (
  p_n IN NUMBER
) RETURN t_num_tab
IS
  v_ids t_num_tab;
BEGIN
  IF p_n IS NULL OR p_n < 1 THEN
    RAISE_APPLICATION_ERROR(-20050,
      'p_n must be a positive number (received ' || NVL(TO_CHAR(p_n), 'NULL') || ')');
  END IF;

  SELECT student_id
    BULK COLLECT INTO v_ids
    FROM students
   WHERE gpa IS NOT NULL
   ORDER BY gpa DESC, student_id
   FETCH FIRST p_n ROWS ONLY;

  IF v_ids.COUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20051,
      'No GPA values found. Run sp_update_student_gpas first.');
  END IF;

  RETURN v_ids;
END fn_top_students;
/
SHOW ERRORS
