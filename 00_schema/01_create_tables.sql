-- =====================================================================
-- 01_create_tables.sql
-- Application : Student Registration and Grading System
-- Course      : INSY 8311 - Database Development with PL/SQL
-- Purpose     : Tables, relationships, constraints, sequences, collection types
-- Re-runnable : YES (existing objects are dropped first; only
--               "object does not exist" errors are ignored)
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

-- ---------------------------------------------------------------------
-- 0. Clean-up (safe to run repeatedly)
--    Ignored errors: ORA-00942 (table), ORA-02289 (sequence), ORA-04043 (type)
--    Any other error is re-raised, so real problems are never hidden.
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_stmt_list IS TABLE OF VARCHAR2(200);
  v_stmts t_stmt_list := t_stmt_list(
    'DROP TABLE perf_test PURGE',
    'DROP TABLE error_log PURGE',
    'DROP TABLE grade_audit PURGE',
    'DROP TABLE enrollments PURGE',
    'DROP TABLE courses PURGE',
    'DROP TABLE students PURGE',
    'DROP TABLE departments PURGE',
    'DROP SEQUENCE seq_student',
    'DROP SEQUENCE seq_enrollment',
    'DROP SEQUENCE seq_audit',
    'DROP SEQUENCE seq_error_log',
    'DROP TYPE t_num_tab FORCE',
    'DROP TYPE t_grade_labels FORCE'
  );
BEGIN
  FOR i IN 1 .. v_stmts.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE v_stmts(i);
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE NOT IN (-942, -2289, -4043) THEN
          RAISE;
        END IF;
    END;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- 1. Sequences
--    seq_student starts at 2001 because sample students use IDs 1001-1012
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_student    START WITH 2001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_enrollment START WITH 1    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_audit      START WITH 1    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_error_log  START WITH 1    INCREMENT BY 1 NOCACHE;

-- ---------------------------------------------------------------------
-- 2. Collection types (schema level, so they can be used in SQL and as
--    parameters / return types of stand-alone procedures and functions)
-- ---------------------------------------------------------------------
-- NESTED TABLE of numbers (list of student ids)
CREATE OR REPLACE TYPE t_num_tab AS TABLE OF NUMBER
/
-- VARRAY with fixed size (the five valid letter grades)
CREATE OR REPLACE TYPE t_grade_labels AS VARRAY(5) OF VARCHAR2(1)
/

-- ---------------------------------------------------------------------
-- 3. Tables
-- ---------------------------------------------------------------------
CREATE TABLE departments (
  dept_id    NUMBER(4)      CONSTRAINT pk_departments PRIMARY KEY,
  dept_name  VARCHAR2(100)  CONSTRAINT nn_dept_name NOT NULL
                            CONSTRAINT uq_dept_name UNIQUE
);

CREATE TABLE students (
  student_id  NUMBER(8)      CONSTRAINT pk_students PRIMARY KEY,
  first_name  VARCHAR2(50)   CONSTRAINT nn_stu_first NOT NULL,
  last_name   VARCHAR2(50)   CONSTRAINT nn_stu_last  NOT NULL,
  email       VARCHAR2(120)  CONSTRAINT nn_stu_email NOT NULL
                             CONSTRAINT uq_stu_email UNIQUE,
  dept_id     NUMBER(4)      CONSTRAINT nn_stu_dept  NOT NULL
                             CONSTRAINT fk_stu_dept  REFERENCES departments (dept_id),
  enrol_date  DATE           DEFAULT SYSDATE CONSTRAINT nn_stu_enrol NOT NULL,
  status      VARCHAR2(10)   DEFAULT 'ACTIVE' CONSTRAINT nn_stu_status NOT NULL
                             CONSTRAINT ck_stu_status
                             CHECK (status IN ('ACTIVE', 'SUSPENDED', 'GRADUATED')),
  gpa         NUMBER(3,2)    CONSTRAINT ck_stu_gpa CHECK (gpa BETWEEN 0 AND 4)
);

CREATE TABLE courses (
  course_id     NUMBER(4)      CONSTRAINT pk_courses PRIMARY KEY,
  course_code   VARCHAR2(12)   CONSTRAINT nn_crs_code  NOT NULL
                               CONSTRAINT uq_crs_code  UNIQUE,
  title         VARCHAR2(120)  CONSTRAINT nn_crs_title NOT NULL,
  credits       NUMBER(1)      CONSTRAINT nn_crs_cred  NOT NULL
                               CONSTRAINT ck_crs_cred  CHECK (credits BETWEEN 1 AND 6),
  dept_id       NUMBER(4)      CONSTRAINT nn_crs_dept  NOT NULL
                               CONSTRAINT fk_crs_dept  REFERENCES departments (dept_id),
  max_capacity  NUMBER(3)      CONSTRAINT nn_crs_cap   NOT NULL
                               CONSTRAINT ck_crs_cap   CHECK (max_capacity > 0)
);

CREATE TABLE enrollments (
  enrollment_id  NUMBER(10)   CONSTRAINT pk_enrollments PRIMARY KEY,
  student_id     NUMBER(8)    CONSTRAINT nn_enr_stu  NOT NULL
                              CONSTRAINT fk_enr_stu  REFERENCES students (student_id),
  course_id      NUMBER(4)    CONSTRAINT nn_enr_crs  NOT NULL
                              CONSTRAINT fk_enr_crs  REFERENCES courses (course_id),
  semester       VARCHAR2(10) CONSTRAINT nn_enr_sem  NOT NULL,
  enrol_date     DATE         DEFAULT SYSDATE,
  marks          NUMBER(5,2)  CONSTRAINT ck_enr_marks CHECK (marks BETWEEN 0 AND 100),
  grade          VARCHAR2(1)  CONSTRAINT ck_enr_grade CHECK (grade IN ('A','B','C','D','F')),
  CONSTRAINT uq_enr_student_course_sem UNIQUE (student_id, course_id, semester)
);

CREATE INDEX idx_enr_course_sem ON enrollments (course_id, semester);
CREATE INDEX idx_enr_student    ON enrollments (student_id);

-- Audit trail for every mark change.
-- No FK on purpose: audit rows must survive even if an enrollment is removed.
CREATE TABLE grade_audit (
  audit_id       NUMBER(10)    CONSTRAINT pk_grade_audit PRIMARY KEY,
  enrollment_id  NUMBER(10)    NOT NULL,
  old_marks      NUMBER(5,2),
  new_marks      NUMBER(5,2),
  old_grade      VARCHAR2(1),
  new_grade      VARCHAR2(1),
  changed_by     VARCHAR2(50)  DEFAULT USER,
  changed_on     TIMESTAMP     DEFAULT SYSTIMESTAMP
);

-- Application error log (written through an autonomous transaction)
CREATE TABLE error_log (
  log_id         NUMBER(10)     CONSTRAINT pk_error_log PRIMARY KEY,
  module_name    VARCHAR2(60)   NOT NULL,
  error_code     NUMBER,
  error_message  VARCHAR2(4000),
  logged_on      TIMESTAMP      DEFAULT SYSTIMESTAMP
);

-- Scratch table used only by sp_perf_compare (row-by-row vs bulk timing)
CREATE TABLE perf_test (
  id       NUMBER,
  payload  VARCHAR2(60)
);

PROMPT === Schema created successfully ===
