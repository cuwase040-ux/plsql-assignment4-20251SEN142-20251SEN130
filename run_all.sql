-- =====================================================================
-- run_all.sql  (convenience script - run from the repository root)
--   SQL*Plus / SQLcl :  @run_all.sql
--
-- Functions are compiled BEFORE procedures because the procedures call
-- them. (If you compile procedures first, Oracle recompiles them
-- automatically on first use, but compiling in this order avoids
-- "invalid object" warnings.)
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT >>> 1. Schema
@00_schema/01_create_tables.sql
@00_schema/02_insert_sample_data.sql

PROMPT >>> 2. Functions
@02_functions/fn_calc_grade.sql
@02_functions/fn_student_gpa.sql
@02_functions/fn_find_student_by_lastname.sql
@02_functions/fn_course_seats_available.sql
@02_functions/fn_top_students.sql
@02_functions/fn_student_full_name.sql

PROMPT >>> 3. Procedures
@01_procedures/sp_log_error.sql
@01_procedures/sp_register_student.sql
@01_procedures/sp_enroll_student.sql
@01_procedures/sp_record_marks.sql
@01_procedures/sp_drop_enrollment.sql
@01_procedures/sp_print_student_transcript.sql
@01_procedures/sp_course_roster_report.sql
@01_procedures/sp_course_grade_distribution.sql
@01_procedures/sp_bulk_assign_grades.sql
@01_procedures/sp_apply_bonus_marks.sql
@01_procedures/sp_update_student_gpas.sql
@01_procedures/sp_bulk_enroll_students.sql
@01_procedures/sp_perf_compare.sql

PROMPT >>> 4. Any invalid objects? (this query should return no rows)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT >>> 5. Tests
@03_tests/test_success_cases.sql
@03_tests/test_error_cases.sql
