# Assignment IV – Advanced Oracle PL/SQL: Student Registration and Grading System

**Course:** Database Development with PL/SQL (INSY 8311)
**Instructor:** Eric Maniraguha  |  **Class group:** `I`

## 1. Group members

| # | Full name | Student ID |
|---|-----------|------------|
| 1 | `Uwase Channel` | `20251SEN130` |
| 2 | `Uwakowe Stephanie` | `20251SEN142` |

## 2. Application description and requirements

A university needs to **register students, enroll them in courses, record marks and grades, and report results**. The database is Oracle; all business logic lives in stored procedures and functions.

**Functional requirements**

| # | Requirement | Implemented by |
|---|-------------|----------------|
| R1 | Register a student with validated data | `sp_register_student` |
| R2 | Enroll a student in a course (only ACTIVE students, only if seats remain, no duplicates) | `sp_enroll_student`, `fn_course_seats_available` |
| R3 | Enroll a whole list of students at once | `sp_bulk_enroll_students` |
| R4 | Record / correct marks, derive the letter grade, keep an audit trail | `sp_record_marks`, `fn_calc_grade`, table `grade_audit` |
| R5 | Withdraw from a course (only if not yet graded) | `sp_drop_enrollment` |
| R6 | Grade a whole class in one operation | `sp_bulk_assign_grades` |
| R7 | Apply bonus marks to a whole class and recompute grades | `sp_apply_bonus_marks` |
| R8 | Compute and store every student's GPA | `fn_student_gpa`, `sp_update_student_gpas` |
| R9 | Rank the best students | `fn_top_students` |
| R10 | Transcript, class roster, grade distribution reports | `sp_print_student_transcript`, `sp_course_roster_report`, `sp_course_grade_distribution` |
| R11 | Look up students | `fn_find_student_by_lastname`, `fn_student_full_name` |
| R12 | Log unexpected errors independently of the caller's transaction | `sp_log_error`, table `error_log` |
| R13 | Show why bulk processing is faster | `sp_perf_compare` |

**Business rules:** marks are 0–100; grades A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, else F; GPA is credit-weighted on a 4.0 scale; a student can be enrolled only once per course per semester; graded enrollments cannot be dropped.

## 3. Database schema

```
DEPARTMENTS 1───< STUDENTS 1───< ENROLLMENTS >───1 COURSES >───1 DEPARTMENTS
                                     │
                          (audit rows copied to GRADE_AUDIT)
ERROR_LOG   – application error log          PERF_TEST – scratch table for timing
```

| Table | Key constraints |
|-------|-----------------|
| `departments` | PK `dept_id`; UNIQUE `dept_name` |
| `students` | PK `student_id`; FK `dept_id`; UNIQUE `email`; CHECK `status IN (ACTIVE, SUSPENDED, GRADUATED)`; CHECK `gpa BETWEEN 0 AND 4` |
| `courses` | PK `course_id`; FK `dept_id`; UNIQUE `course_code`; CHECK `credits 1–6`, `max_capacity > 0` |
| `enrollments` | PK `enrollment_id`; FK `student_id`, `course_id`; UNIQUE `(student_id, course_id, semester)`; CHECK `marks 0–100`; CHECK `grade IN (A,B,C,D,F)` |
| `grade_audit`, `error_log`, `perf_test` | supporting tables |

Schema-level collection types: `t_num_tab` (nested table of NUMBER), `t_grade_labels` (VARRAY(5)). Full DDL: [`00_schema/01_create_tables.sql`](00_schema/01_create_tables.sql).

## 4. How to run

Requires Oracle Database 12c or later (uses `FETCH FIRST n ROWS ONLY`) with SQL*Plus, SQLcl or SQL Developer (run as a script, F5).

**One command (from the repository root):**
```sql
@run_all.sql
```

**Step by step:**

1. `00_schema/01_create_tables.sql`
2. `00_schema/02_insert_sample_data.sql`
3. Compile the **functions** in `02_functions/` (all 6 files)
4. Compile the **procedures** in `01_procedures/` (all 13 files)
5. Run `03_tests/test_success_cases.sql`, then `03_tests/test_error_cases.sql`
6. Check results and capture screenshots into `screenshots/`

> **Compile order note:** the procedures call the functions, so the functions are compiled first. If the procedures are compiled first, Oracle marks them INVALID and recompiles them automatically on first use, so the result is the same. After compiling, `SELECT object_name FROM user_objects WHERE status='INVALID'` should return no rows.

Both test scripts end with `ROLLBACK`, so they can be re-run any number of times.

## 5. Where each required concept is demonstrated

| Requirement | File(s) |
|-------------|---------|
| **User-defined record** | `sp_print_student_transcript` (`r_transcript_line`) |
| **%ROWTYPE record** | `sp_register_student`, `sp_enroll_student`, `sp_record_marks`, `fn_student_full_name`, `sp_bulk_assign_grades` |
| **Associative array** | `sp_course_grade_distribution` (indexed by VARCHAR2), `sp_update_student_gpas`, `sp_bulk_assign_grades` |
| **Nested table** | `t_num_tab` – `fn_top_students` (return), `sp_bulk_enroll_students` (parameter), `sp_apply_bonus_marks` |
| **VARRAY** | `t_grade_labels` in `sp_course_grade_distribution` |
| **Implicit cursor + `SQL%ROWCOUNT / FOUND / NOTFOUND`** | INSERT: `sp_register_student`, `sp_enroll_student` · UPDATE: `sp_record_marks` (`%FOUND`) · DELETE: `sp_drop_enrollment` (`%NOTFOUND`) |
| **Explicit cursor, OPEN/FETCH/CLOSE** | `sp_print_student_transcript` (with parameter, `%NOTFOUND`, `%ROWCOUNT`, `%ISOPEN`) |
| **Explicit cursor FOR loop** | `sp_course_roster_report`, `fn_student_gpa` |
| **BULK COLLECT** | `fn_top_students`, `sp_bulk_assign_grades`, `sp_apply_bonus_marks`, `sp_update_student_gpas` (with `LIMIT`) |
| **FORALL** (UPDATE / INSERT) | `sp_bulk_assign_grades`, `sp_apply_bonus_marks`, `sp_update_student_gpas`, `sp_bulk_enroll_students`, `sp_perf_compare` |
| **Bulk DML error handling** (`SAVE EXCEPTIONS`, `SQL%BULK_EXCEPTIONS`, ORA-24381) | `sp_apply_bonus_marks`, `sp_bulk_enroll_students`, `sp_bulk_assign_grades` · tested in E12a/E12b |
| **Stored procedures with IN/OUT parameters** | all 13 in `01_procedures/` |
| **Functions called from SQL / PL/SQL** | `fn_calc_grade`, `fn_top_students` (via `TABLE()`), etc. – tests 01-03, 08 |
| **Predefined exceptions** | `NO_DATA_FOUND`, `TOO_MANY_ROWS`, `DUP_VAL_ON_INDEX`, `ZERO_DIVIDE` – tests E00, E03, E07, E08 |
| **User-defined exceptions** | `e_invalid_name`, `e_student_inactive`, `e_course_full`, `e_enrollment_missing`, `e_already_graded`, … |
| **RAISE_APPLICATION_ERROR** | codes -20001 … -20801 (table in `docs/IMPLEMENTATION_NOTES.md`) |

## 6. Repository layout

```
plsql-assignment4-<ID1>-<ID2>/
├── README.md
├── .gitignore
├── run_all.sql
├── 00_schema/        01_create_tables.sql, 02_insert_sample_data.sql
├── 01_procedures/    13 files, one per procedure
├── 02_functions/     6 files, one per function
├── 03_tests/         test_success_cases.sql, test_error_cases.sql
├── screenshots/      <test_name>_output.png
└── docs/             IMPLEMENTATION_NOTES.md
```

## 7. Use of AI assistance (academic-integrity statement)

An AI assistant (Claude, by Anthropic) was used to help draft the initial structure of this repository: the schema, the PL/SQL source, the test scripts and the documentation. Both group members then reviewed the code, ran it against Oracle, took the screenshots, and are able to explain every procedure and function individually. 

## 8. Contribution

| Member | Contribution |
|--------|--------------|
| `Uwakowe Stephanie` | ` schema, sample data, functions, tests` |
| `Uwase Channel` | ` procedures, bulk processing, documentation, screenshots` |
