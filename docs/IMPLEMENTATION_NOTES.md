# Implementation and Performance Notes

## 1. Design overview

All business logic is in **stand-alone stored procedures and functions** (one file each). Shared collection types (`t_num_tab`, `t_grade_labels`) are schema-level types so they can be used as parameters / return types and inside SQL.

Layering:

```
fn_calc_grade ─┬─> sp_record_marks, sp_bulk_assign_grades, sp_apply_bonus_marks
fn_student_gpa ─┬─> sp_update_student_gpas, sp_print_student_transcript
fn_course_seats_available ─┬─> sp_enroll_student, sp_bulk_enroll_students, sp_course_roster_report
sp_log_error  ─────> called by every procedure for UNEXPECTED errors
```

Transaction policy: procedures **do not COMMIT** (the caller owns the transaction). The only exception is `sp_log_error`, which uses `PRAGMA AUTONOMOUS_TRANSACTION` so an error record survives a caller's rollback.

## 2. Records

| Kind | Where | Why |
|------|-------|-----|
| User-defined record `r_transcript_line` | `sp_print_student_transcript` | One variable holds one joined transcript row fetched from the explicit cursor |
| `%ROWTYPE` | `sp_register_student` | Build a `students` row field by field, then `INSERT INTO students VALUES v_student` |
| `%ROWTYPE` | `sp_enroll_student`, `sp_record_marks`, `fn_student_full_name` | Fetch the whole row once and use any column afterwards (also keeps the *old* row for the audit trail) |
| Collection of `%ROWTYPE` | `sp_bulk_assign_grades` | `BULK COLLECT INTO` a nested table of whole rows |

## 3. Collections

| Type | Where | Why |
|------|-------|-----|
| Nested table `t_num_tab` (schema level) | `fn_top_students` returns it; `sp_bulk_enroll_students` takes it as a parameter | Can be passed between programs and queried with `TABLE()` |
| Nested tables (local) | `sp_apply_bonus_marks`, `sp_perf_compare` | Hold ids / marks / grades for bulk operations |
| Associative array, `INDEX BY VARCHAR2` | `sp_course_grade_distribution` | grade letter → count lookup |
| Associative array, `INDEX BY PLS_INTEGER` | `sp_update_student_gpas`, `sp_bulk_assign_grades` | Parallel arrays that drive `FORALL` |
| VARRAY `t_grade_labels(5)` | `sp_course_grade_distribution` | A fixed, ordered list of the 5 valid grades |

## 4. Cursors

**Implicit cursors** (attributes read immediately after the statement):

| Statement | Procedure | Attribute used |
|-----------|-----------|----------------|
| INSERT | `sp_register_student`, `sp_enroll_student` | `SQL%ROWCOUNT` |
| UPDATE | `sp_record_marks` | `SQL%FOUND`, `SQL%ROWCOUNT` |
| DELETE | `sp_drop_enrollment` | `SQL%ROWCOUNT`, `SQL%NOTFOUND` (then a COUNT query decides between "not found" and "already graded", so the error message is accurate) |

**Explicit cursors:**

* `sp_print_student_transcript` – parameterised cursor, manual `OPEN / FETCH / CLOSE`, `%NOTFOUND`, `%ROWCOUNT`; `%ISOPEN` check in the exception handler so a cursor is never leaked.
* `sp_course_roster_report`, `fn_student_gpa` – cursor `FOR` loops.
* `sp_update_student_gpas` – cursor fetched in batches of 100 with `BULK COLLECT ... LIMIT`.

## 5. Bulk processing and performance

### Why bulk processing is faster

PL/SQL and SQL run in two different engines. Every SQL statement executed inside a PL/SQL loop causes a **context switch** from the PL/SQL engine to the SQL engine and back.

* **Row-by-row** (`FOR ... LOOP INSERT/UPDATE ... END LOOP`): N rows = N context switches and N statement executions.
* **`BULK COLLECT`**: the SQL engine returns *all* rows in **one** switch instead of one `FETCH` per row.
* **`FORALL`**: the whole collection is sent to the SQL engine in **one** bulk bind, so N DML operations cost **one** switch.

`sp_perf_compare(p_rows)` measures this directly: it inserts `p_rows` rows into `perf_test` once with a plain loop and once with `FORALL` and prints both timings. Typical result: FORALL is several times faster, and the gap grows with the row count. (Absolute numbers depend on the machine; record yours from `test_success_cases.sql`, TEST 13, and paste them below.)

| Rows | Row-by-row (ms) | FORALL (ms) | Speed-up |
|------|-----------------|-------------|----------|
| 20,000 | `<fill in>` | `<fill in>` | `<fill in>` |

### Memory considerations

* `BULK COLLECT` without `LIMIT` loads every row into PGA memory. That is fine for one course (dozens of rows) but not for millions of rows. `sp_update_student_gpas` shows the scalable pattern: `FETCH ... BULK COLLECT INTO ... LIMIT 100` inside a loop.
* `sp_update_student_gpas` still calls `fn_student_gpa` once per student (a query per student). This keeps the GPA logic in one place and is acceptable at this scale; for very large volumes it could be rewritten as a single set-based `MERGE`.

### Bulk DML error handling

`FORALL ... SAVE EXCEPTIONS` lets the statement continue past failing rows. After the loop Oracle raises **ORA-24381**, which each bulk procedure catches (`PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381)`). The handler:

1. reads `SQL%ROWCOUNT` (rows that **succeeded**),
2. reads `SQL%BULK_EXCEPTIONS.COUNT` and, for each failure, `ERROR_INDEX` (which element) and `ERROR_CODE` (which error – note it is positive, so we use `-ERROR_CODE`),
3. maps the index back to the business key (enrollment id / student id), prints it, writes it to `error_log` and returns the counts through OUT parameters.

Failures are therefore **reported, never ignored**. Demonstrated by tests:

* **E12a** – `sp_apply_bonus_marks(101, '2026-A', 7, ...)`: one student would reach 102 marks → CHECK constraint ORA-02290 → 5 rows updated, 1 reported.
* **E12b** – `sp_bulk_enroll_students` with a duplicate (ORA-00001) and an unknown student (ORA-02291) → 1 enrolled, 2 reported.

## 6. Exception handling

Pattern used in every procedure:

1. **Validate first** and raise `RAISE_APPLICATION_ERROR` (or a user-defined exception translated by the handler) with a message that names the offending value.
2. **Translate predefined/Oracle errors** into meaningful ones (`NO_DATA_FOUND` → "student X does not exist", `DUP_VAL_ON_INDEX` → "already enrolled", ORA-02291 → "department does not exist").
3. **`WHEN OTHERS`** only for *unexpected* errors: log through `sp_log_error`, then **`RAISE`** – the error is never swallowed. Application errors (-20000..-20999) are not logged there because they are expected and already carry a clear message.
4. Functions **raise** instead of returning a default: `fn_calc_grade(101)` raises -20010 instead of returning `'A'`; `fn_student_gpa` for a student without graded courses raises -20021 instead of returning a misleading `0`. Callers that can legitimately continue (`sp_update_student_gpas`, `sp_print_student_transcript`) catch that specific code and **count or print** it.

| Exception type | Examples |
|----------------|----------|
| Predefined | `NO_DATA_FOUND`, `TOO_MANY_ROWS`, `DUP_VAL_ON_INDEX`, `ZERO_DIVIDE` |
| User-defined | `e_invalid_name`, `e_student_inactive`, `e_course_full`, `e_enrollment_missing`, `e_already_graded` |
| Mapped with `EXCEPTION_INIT` | `e_dept_not_found` (-2291), `e_bulk_errors` (-24381), `e_no_graded` (-20021) |
| `RAISE_APPLICATION_ERROR` | all codes below |

### Error code reference

| Code | Raised by | Meaning |
|------|-----------|---------|
| -20001 / -20002 / -20003 | `sp_register_student` | unknown department / duplicate e-mail / blank name |
| -20010 | `fn_calc_grade` | marks NULL or outside 0–100 |
| -20020 / -20021 | `fn_student_gpa` | student not found / no graded courses |
| -20031 / -20032 | `fn_find_student_by_lastname` | no match / several matches |
| -20040 | `fn_course_seats_available` | course not found |
| -20050 / -20051 | `fn_top_students` | invalid N / no GPAs computed yet |
| -20061 | `fn_student_full_name` | student not found |
| -20101 … -20105 | `sp_enroll_student` | student missing / course missing / student not ACTIVE / course full / duplicate |
| -20201 | `sp_record_marks` | enrollment not found |
| -20301 / -20302 | `sp_drop_enrollment` | nothing to drop / already graded |
| -20401 | `sp_print_student_transcript` | student not found |
| -20451 | `sp_course_roster_report` | course not found |
| -20501 | `sp_course_grade_distribution` | course not found |
| -20551 | `sp_bulk_assign_grades` | course not found |
| -20601 / -20602 | `sp_apply_bonus_marks` | invalid bonus / course not found |
| -20701 / -20702 / -20703 | `sp_bulk_enroll_students` | empty list / course not found / not enough seats |
| -20801 | `sp_perf_compare` | invalid row count |

## 7. Testing

* `03_tests/test_success_cases.sql` – 13 numbered tests, each prints its own header; ends with `ROLLBACK`.
* `03_tests/test_error_cases.sql` – every case prints `PASS` or `FAIL` after comparing `SQLCODE` with the expected code; ends with `ROLLBACK`. `error_log` rows persist by design (autonomous transaction).
* Functions are called from SQL (`SELECT fn_calc_grade(...) FROM dual`, `TABLE(fn_top_students(3))`) and from anonymous blocks.

Screenshots (`screenshots/`): one per test header, e.g. `test01_fn_calc_grade_output.png`, `test05_bulk_assign_grades_output.png`, `E08_enroll_errors_output.png`, `E12_bulk_dml_errors_output.png`.

## 8. Known limitations

* Seat availability is checked and then inserted without a lock, so two simultaneous sessions could both take the last seat. A production system would lock the `courses` row (`SELECT ... FOR UPDATE`) first.
* `sp_apply_bonus_marks` updates marks and grades but does not write `grade_audit` rows (single-row `sp_record_marks` does).
* Semester is a free-text label (`'2026-A'`); a `semesters` lookup table would be the next improvement.
