-- =====================================================================
-- test_success_cases.sql
-- Successful execution of every function and procedure.
-- Run AFTER: tables, sample data, functions, procedures.
-- Take one screenshot per TEST block (see screenshots/ naming in README).
-- All changes are rolled back at the end, so the script can be re-run.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK ON

PROMPT
PROMPT ##### TEST 01: fn_calc_grade called from a SQL statement #####
SELECT marks, fn_calc_grade(marks) AS grade
  FROM (SELECT 100 AS marks FROM dual UNION ALL
        SELECT 90 FROM dual UNION ALL SELECT 89.5 FROM dual UNION ALL
        SELECT 75 FROM dual UNION ALL SELECT 60 FROM dual UNION ALL
        SELECT 59 FROM dual UNION ALL SELECT 0 FROM dual);

PROMPT
PROMPT ##### TEST 02: fn_student_full_name, fn_find_student_by_lastname (%ROWTYPE, SELECT INTO) #####
SELECT fn_student_full_name(1001)               AS full_name,
       fn_find_student_by_lastname('uwase')     AS id_of_uwase
  FROM dual;

PROMPT
PROMPT ##### TEST 03: fn_course_seats_available #####
SELECT course_id, course_code, max_capacity,
       fn_course_seats_available(course_id, '2026-A') AS seats_left
  FROM courses
 ORDER BY course_id;

PROMPT
PROMPT ##### TEST 04: sp_register_student + sp_enroll_student + sp_record_marks + sp_drop_enrollment #####
DECLARE
  v_student_id students.student_id%TYPE;
  v_enr_101    enrollments.enrollment_id%TYPE;
  v_enr_103    enrollments.enrollment_id%TYPE;
  v_grade      enrollments.grade%TYPE;
  v_deleted    PLS_INTEGER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- register ---');
  sp_register_student('Test', 'Student', 'Test.Student@auca.ac.rw', 1, v_student_id);

  DBMS_OUTPUT.PUT_LINE('--- enroll in two courses ---');
  sp_enroll_student(v_student_id, 101, '2026-A', v_enr_101);
  sp_enroll_student(v_student_id, 103, '2026-A', v_enr_103);

  DBMS_OUTPUT.PUT_LINE('--- record marks (OUT parameter returns the grade) ---');
  sp_record_marks(v_enr_101, 88, v_grade);
  DBMS_OUTPUT.PUT_LINE('Grade returned by OUT parameter: ' || v_grade);
  sp_record_marks(v_enr_101, 93, v_grade);              -- correction -> audit row #2
  DBMS_OUTPUT.PUT_LINE('Corrected grade: ' || v_grade);

  DBMS_OUTPUT.PUT_LINE('--- drop the ungraded enrollment (SQL%ROWCOUNT / SQL%NOTFOUND) ---');
  sp_drop_enrollment(v_student_id, 103, '2026-A', v_deleted);
  DBMS_OUTPUT.PUT_LINE('OUT parameter rows deleted: ' || v_deleted);
END;
/

PROMPT Grade audit rows written by sp_record_marks:
SELECT audit_id, enrollment_id, old_marks, new_marks, old_grade, new_grade
  FROM grade_audit
 ORDER BY audit_id;

PROMPT
PROMPT ##### TEST 05: sp_bulk_assign_grades (BULK COLLECT + FORALL), course 105 #####
DECLARE
  v_graded PLS_INTEGER;
  v_failed PLS_INTEGER;
BEGIN
  sp_bulk_assign_grades(105, '2026-A', v_graded, v_failed);
  DBMS_OUTPUT.PUT_LINE('graded=' || v_graded || ' failed=' || v_failed);
END;
/
SELECT enrollment_id, student_id, marks, grade
  FROM enrollments
 WHERE course_id = 105 AND semester = '2026-A'
 ORDER BY enrollment_id;

PROMPT
PROMPT ##### TEST 06: sp_apply_bonus_marks (bulk update, bonus +2, course 102) #####
DECLARE
  v_updated PLS_INTEGER;
  v_failed  PLS_INTEGER;
BEGIN
  sp_apply_bonus_marks(102, '2026-A', 2, v_updated, v_failed);
  DBMS_OUTPUT.PUT_LINE('updated=' || v_updated || ' failed=' || v_failed);
END;
/
SELECT student_id, marks, grade FROM enrollments
 WHERE course_id = 102 AND semester = '2026-A' ORDER BY student_id;

PROMPT
PROMPT ##### TEST 07: sp_update_student_gpas (BULK COLLECT LIMIT + FORALL) #####
DECLARE
  v_updated PLS_INTEGER;
  v_skipped PLS_INTEGER;
BEGIN
  sp_update_student_gpas(v_updated, v_skipped);
  DBMS_OUTPUT.PUT_LINE('updated=' || v_updated || ' skipped=' || v_skipped);
END;
/
SELECT student_id, first_name, last_name, status, gpa
  FROM students
 ORDER BY student_id;

PROMPT
PROMPT ##### TEST 08: fn_student_gpa and fn_top_students (nested table queried with TABLE()) #####
SELECT fn_student_gpa(1001) AS gpa_1001 FROM dual;

SELECT s.student_id, s.first_name || ' ' || s.last_name AS student, s.gpa
  FROM TABLE(fn_top_students(3)) t
  JOIN students s ON s.student_id = t.COLUMN_VALUE
 ORDER BY s.gpa DESC, s.student_id;

PROMPT
PROMPT ##### TEST 09: Explicit cursors - transcript (OPEN/FETCH/CLOSE) #####
BEGIN
  sp_print_student_transcript(1001);
END;
/

PROMPT
PROMPT ##### TEST 10: Explicit cursor FOR loop - course roster #####
BEGIN
  sp_course_roster_report(101, '2026-A');
END;
/

PROMPT
PROMPT ##### TEST 11: Associative array + VARRAY - grade distribution #####
BEGIN
  sp_course_grade_distribution(101, '2026-A');
END;
/

PROMPT
PROMPT ##### TEST 12: sp_bulk_enroll_students (nested table parameter, FORALL INSERT) #####
DECLARE
  v_enrolled PLS_INTEGER;
  v_failed   PLS_INTEGER;
BEGIN
  sp_bulk_enroll_students(108, '2026-A', t_num_tab(1003, 1006, 1009), v_enrolled, v_failed);
  DBMS_OUTPUT.PUT_LINE('enrolled=' || v_enrolled || ' failed=' || v_failed);
END;
/
BEGIN
  sp_course_roster_report(108, '2026-A');
END;
/

PROMPT
PROMPT ##### TEST 13: sp_perf_compare - row-by-row vs FORALL (20,000 rows) #####
BEGIN
  sp_perf_compare(20000);
END;
/

PROMPT
PROMPT ##### Undo every change made by this script #####
ROLLBACK;
PROMPT === All success tests finished (changes rolled back) ===
