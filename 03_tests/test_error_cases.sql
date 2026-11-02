-- =====================================================================
-- test_error_cases.sql
-- Every test forces an error and checks that the EXPECTED error code is
-- raised. Each line prints PASS or FAIL, so the output is easy to screenshot.
-- Run AFTER: tables, sample data, functions, procedures.
-- All data changes are rolled back at the end.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

PROMPT
PROMPT ##### E00: Predefined exceptions raised directly (NO_DATA_FOUND, TOO_MANY_ROWS, ZERO_DIVIDE) #####
DECLARE
  v_id   students.student_id%TYPE;
  v_n    NUMBER;
  v_zero NUMBER := 0;
BEGIN
  BEGIN
    SELECT student_id INTO v_id FROM students WHERE last_name = 'DoesNotExist';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('PASS E00a: NO_DATA_FOUND (ORA' || SQLCODE || ')');
  END;

  BEGIN
    SELECT student_id INTO v_id FROM students WHERE last_name = 'Mugisha';
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      DBMS_OUTPUT.PUT_LINE('PASS E00b: TOO_MANY_ROWS (ORA' || SQLCODE || ')');
  END;

  BEGIN
    v_n := 10 / v_zero;               -- divisor is 0 at run time
    DBMS_OUTPUT.PUT_LINE('FAIL E00c: no error raised');
  EXCEPTION
    WHEN ZERO_DIVIDE THEN
      DBMS_OUTPUT.PUT_LINE('PASS E00c: ZERO_DIVIDE (ORA' || SQLCODE || ')');
  END;
END;
/

PROMPT
PROMPT ##### E01-E02: Function errors #####
DECLARE
  v_text VARCHAR2(10);
  v_num  NUMBER;
BEGIN
  -- E01a marks above 100
  BEGIN
    v_text := fn_calc_grade(101);
    DBMS_OUTPUT.PUT_LINE('FAIL E01a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20010 THEN 'PASS' ELSE 'FAIL' END
      || ' E01a fn_calc_grade(101): ' || SQLERRM);
  END;
  -- E01b NULL marks
  BEGIN
    v_text := fn_calc_grade(NULL);
    DBMS_OUTPUT.PUT_LINE('FAIL E01b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20010 THEN 'PASS' ELSE 'FAIL' END
      || ' E01b fn_calc_grade(NULL): ' || SQLERRM);
  END;
  -- E02a GPA of unknown student
  BEGIN
    v_num := fn_student_gpa(9999);
    DBMS_OUTPUT.PUT_LINE('FAIL E02a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20020 THEN 'PASS' ELSE 'FAIL' END
      || ' E02a fn_student_gpa(9999): ' || SQLERRM);
  END;
  -- E02b GPA of a student with no graded courses (1012 has no enrollments)
  BEGIN
    v_num := fn_student_gpa(1012);
    DBMS_OUTPUT.PUT_LINE('FAIL E02b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20021 THEN 'PASS' ELSE 'FAIL' END
      || ' E02b fn_student_gpa(1012): ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E03-E06: Lookup functions #####
DECLARE
  v_num  NUMBER;
  v_text VARCHAR2(100);
  v_tab  t_num_tab;
BEGIN
  BEGIN
    v_num := fn_find_student_by_lastname('Nobody');
    DBMS_OUTPUT.PUT_LINE('FAIL E03a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20031 THEN 'PASS' ELSE 'FAIL' END
      || ' E03a NO_DATA_FOUND mapped: ' || SQLERRM);
  END;
  BEGIN
    v_num := fn_find_student_by_lastname('Mugisha');
    DBMS_OUTPUT.PUT_LINE('FAIL E03b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20032 THEN 'PASS' ELSE 'FAIL' END
      || ' E03b TOO_MANY_ROWS mapped: ' || SQLERRM);
  END;
  BEGIN
    v_num := fn_course_seats_available(999, '2026-A');
    DBMS_OUTPUT.PUT_LINE('FAIL E04: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20040 THEN 'PASS' ELSE 'FAIL' END
      || ' E04 fn_course_seats_available(999): ' || SQLERRM);
  END;
  BEGIN
    v_tab := fn_top_students(0);
    DBMS_OUTPUT.PUT_LINE('FAIL E05a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20050 THEN 'PASS' ELSE 'FAIL' END
      || ' E05a fn_top_students(0): ' || SQLERRM);
  END;
  -- GPAs are still NULL (sample data), so no ranking is possible
  BEGIN
    v_tab := fn_top_students(3);
    DBMS_OUTPUT.PUT_LINE('FAIL E05b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20051 THEN 'PASS' ELSE 'FAIL' END
      || ' E05b fn_top_students before GPAs exist: ' || SQLERRM);
  END;
  BEGIN
    v_text := fn_student_full_name(9999);
    DBMS_OUTPUT.PUT_LINE('FAIL E06: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20061 THEN 'PASS' ELSE 'FAIL' END
      || ' E06 fn_student_full_name(9999): ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E07: sp_register_student errors #####
DECLARE
  v_id students.student_id%TYPE;
BEGIN
  BEGIN
    sp_register_student('Bad', 'Dept', 'bad.dept@auca.ac.rw', 99, v_id);
    DBMS_OUTPUT.PUT_LINE('FAIL E07a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20001 THEN 'PASS' ELSE 'FAIL' END
      || ' E07a unknown department: ' || SQLERRM);
  END;
  BEGIN
    sp_register_student('Dup', 'Email', 'alice.uwase@auca.ac.rw', 1, v_id);
    DBMS_OUTPUT.PUT_LINE('FAIL E07b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20002 THEN 'PASS' ELSE 'FAIL' END
      || ' E07b duplicate e-mail: ' || SQLERRM);
  END;
  BEGIN
    sp_register_student('   ', 'Blank', 'blank.name@auca.ac.rw', 1, v_id);
    DBMS_OUTPUT.PUT_LINE('FAIL E07c: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20003 THEN 'PASS' ELSE 'FAIL' END
      || ' E07c blank first name: ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E08: sp_enroll_student errors #####
DECLARE
  v_enr enrollments.enrollment_id%TYPE;
BEGIN
  BEGIN
    sp_enroll_student(9999, 101, '2026-A', v_enr);
    DBMS_OUTPUT.PUT_LINE('FAIL E08a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20101 THEN 'PASS' ELSE 'FAIL' END
      || ' E08a unknown student: ' || SQLERRM);
  END;
  BEGIN
    sp_enroll_student(1001, 999, '2026-A', v_enr);
    DBMS_OUTPUT.PUT_LINE('FAIL E08b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20102 THEN 'PASS' ELSE 'FAIL' END
      || ' E08b unknown course: ' || SQLERRM);
  END;
  BEGIN
    sp_enroll_student(1012, 101, '2026-A', v_enr);      -- suspended student
    DBMS_OUTPUT.PUT_LINE('FAIL E08c: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20103 THEN 'PASS' ELSE 'FAIL' END
      || ' E08c suspended student: ' || SQLERRM);
  END;
  BEGIN
    sp_enroll_student(1002, 107, '2026-A', v_enr);      -- course 107 is full
    DBMS_OUTPUT.PUT_LINE('FAIL E08d: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20104 THEN 'PASS' ELSE 'FAIL' END
      || ' E08d course full: ' || SQLERRM);
  END;
  BEGIN
    sp_enroll_student(1001, 101, '2026-A', v_enr);      -- already enrolled
    DBMS_OUTPUT.PUT_LINE('FAIL E08e: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20105 THEN 'PASS' ELSE 'FAIL' END
      || ' E08e duplicate enrollment: ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E09: sp_record_marks and sp_drop_enrollment errors #####
DECLARE
  v_grade   enrollments.grade%TYPE;
  v_deleted PLS_INTEGER;
BEGIN
  BEGIN
    sp_record_marks(999999, 70, v_grade);
    DBMS_OUTPUT.PUT_LINE('FAIL E09a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20201 THEN 'PASS' ELSE 'FAIL' END
      || ' E09a unknown enrollment: ' || SQLERRM);
  END;
  BEGIN
    sp_record_marks(1, 150, v_grade);
    DBMS_OUTPUT.PUT_LINE('FAIL E09b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20010 THEN 'PASS' ELSE 'FAIL' END
      || ' E09b marks out of range: ' || SQLERRM);
  END;
  BEGIN
    sp_drop_enrollment(9999, 101, '2026-A', v_deleted);  -- SQL%NOTFOUND path
    DBMS_OUTPUT.PUT_LINE('FAIL E09c: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20301 THEN 'PASS' ELSE 'FAIL' END
      || ' E09c nothing to drop: ' || SQLERRM);
  END;
  BEGIN
    sp_drop_enrollment(1001, 101, '2026-A', v_deleted);  -- already graded
    DBMS_OUTPUT.PUT_LINE('FAIL E09d: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20302 THEN 'PASS' ELSE 'FAIL' END
      || ' E09d graded enrollment: ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E10: Report procedures with bad input #####
BEGIN
  BEGIN
    sp_print_student_transcript(9999);
    DBMS_OUTPUT.PUT_LINE('FAIL E10a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20401 THEN 'PASS' ELSE 'FAIL' END
      || ' E10a transcript, unknown student: ' || SQLERRM);
  END;
  BEGIN
    sp_course_roster_report(999, '2026-A');
    DBMS_OUTPUT.PUT_LINE('FAIL E10b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20451 THEN 'PASS' ELSE 'FAIL' END
      || ' E10b roster, unknown course: ' || SQLERRM);
  END;
  BEGIN
    sp_course_grade_distribution(999, '2026-A');
    DBMS_OUTPUT.PUT_LINE('FAIL E10c: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20501 THEN 'PASS' ELSE 'FAIL' END
      || ' E10c distribution, unknown course: ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E11: Bulk procedures - validation errors #####
DECLARE
  v_a PLS_INTEGER;
  v_b PLS_INTEGER;
BEGIN
  BEGIN
    sp_bulk_assign_grades(999, '2026-A', v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('FAIL E11a: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20551 THEN 'PASS' ELSE 'FAIL' END
      || ' E11a bulk grade, unknown course: ' || SQLERRM);
  END;
  BEGIN
    sp_apply_bonus_marks(101, '2026-A', 0, v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('FAIL E11b: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20601 THEN 'PASS' ELSE 'FAIL' END
      || ' E11b zero bonus: ' || SQLERRM);
  END;
  BEGIN
    sp_apply_bonus_marks(999, '2026-A', 5, v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('FAIL E11c: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20602 THEN 'PASS' ELSE 'FAIL' END
      || ' E11c bonus, unknown course: ' || SQLERRM);
  END;
  BEGIN
    sp_bulk_enroll_students(108, '2026-A', t_num_tab(), v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('FAIL E11d: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20701 THEN 'PASS' ELSE 'FAIL' END
      || ' E11d empty student list: ' || SQLERRM);
  END;
  BEGIN
    sp_bulk_enroll_students(999, '2026-A', t_num_tab(1001), v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('FAIL E11e: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20702 THEN 'PASS' ELSE 'FAIL' END
      || ' E11e bulk enroll, unknown course: ' || SQLERRM);
  END;
  BEGIN
    -- course 107 has no free seat, so a 2-student request cannot fit
    sp_bulk_enroll_students(107, '2026-A', t_num_tab(1002, 1003), v_a, v_b);
    DBMS_OUTPUT.PUT_LINE('FAIL E11f: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20703 THEN 'PASS' ELSE 'FAIL' END
      || ' E11f not enough seats: ' || SQLERRM);
  END;
  BEGIN
    sp_perf_compare(0);
    DBMS_OUTPUT.PUT_LINE('FAIL E11g: no error raised');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN SQLCODE = -20801 THEN 'PASS' ELSE 'FAIL' END
      || ' E11g sp_perf_compare(0): ' || SQLERRM);
  END;
END;
/

PROMPT
PROMPT ##### E12: BULK DML ERRORS - FORALL ... SAVE EXCEPTIONS (partial success) #####
PROMPT E12a: bonus +7 in course 101: Diane (95 -> 102) violates CHECK ck_enr_marks (ORA-02290)
DECLARE
  v_updated PLS_INTEGER;
  v_failed  PLS_INTEGER;
BEGIN
  sp_apply_bonus_marks(101, '2026-A', 7, v_updated, v_failed);
  DBMS_OUTPUT.PUT_LINE(CASE WHEN v_failed = 1 AND v_updated = 5 THEN 'PASS' ELSE 'FAIL' END
    || ' E12a updated=' || v_updated || ' (expected 5), failed=' || v_failed || ' (expected 1)');
END;
/
SELECT student_id, marks, grade
  FROM enrollments
 WHERE course_id = 101 AND semester = '2026-A'
 ORDER BY student_id;

PROMPT E12b: bulk enroll with a duplicate (1001) and an unknown id (9999): only 1005 is valid
DECLARE
  v_enrolled PLS_INTEGER;
  v_failed   PLS_INTEGER;
BEGIN
  sp_bulk_enroll_students(101, '2026-A', t_num_tab(1001, 9999, 1005), v_enrolled, v_failed);
  DBMS_OUTPUT.PUT_LINE(CASE WHEN v_enrolled = 1 AND v_failed = 2 THEN 'PASS' ELSE 'FAIL' END
    || ' E12b enrolled=' || v_enrolled || ' (expected 1), failed=' || v_failed || ' (expected 2)');
END;
/

PROMPT
PROMPT ##### E13: error_log written by sp_log_error (autonomous transaction) #####
SELECT log_id, module_name, error_code, SUBSTR(error_message, 1, 90) AS error_message
  FROM error_log
 ORDER BY log_id;

PROMPT
PROMPT ##### Undo every data change made by this script #####
ROLLBACK;
-- error_log rows are kept on purpose: sp_log_error commits in its own autonomous transaction.
PROMPT === All error tests finished (data changes rolled back) ===
