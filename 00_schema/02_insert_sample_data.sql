-- =====================================================================
-- 02_insert_sample_data.sql
-- Sample data for the Student Registration and Grading System
--
-- Deliberate design choices (used by the test files):
--   * Two students share the last name 'Mugisha'   -> TOO_MANY_ROWS demo
--   * Student 1012 is SUSPENDED                      -> enrolment rule demo
--   * Course 107 has capacity 3 and is already full  -> "course full" demo
--   * Course 105 has marks but NO grades yet         -> sp_bulk_assign_grades demo
--   * Student 1012 has no enrolments at all          -> "no graded courses" demo
--   * Student 1011 has 95 marks in course 101        -> bonus overflow (>100) demo
-- =====================================================================

-- ---------- Departments ----------
INSERT INTO departments (dept_id, dept_name) VALUES (1, 'Information Systems');
INSERT INTO departments (dept_id, dept_name) VALUES (2, 'Business Administration');
INSERT INTO departments (dept_id, dept_name) VALUES (3, 'Software Engineering');

-- ---------- Students ----------
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1001, 'Alice',    'Uwase',        'alice.uwase@auca.ac.rw',        1, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1002, 'Eric',     'Mugisha',      'eric.mugisha@auca.ac.rw',       1, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1003, 'Grace',    'Mugisha',      'grace.mugisha@auca.ac.rw',      2, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1004, 'David',    'Habimana',     'david.habimana@auca.ac.rw',     1, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1005, 'Sandrine', 'Ingabire',     'sandrine.ingabire@auca.ac.rw',  3, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1006, 'Patrick',  'Niyonzima',    'patrick.niyonzima@auca.ac.rw',  2, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1007, 'Chantal',  'Mukamana',     'chantal.mukamana@auca.ac.rw',   1, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1008, 'Jean',     'Nshimiyimana', 'jean.nshimiyimana@auca.ac.rw',  3, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1009, 'Aline',    'Uwimana',      'aline.uwimana@auca.ac.rw',      2, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1010, 'Emmanuel', 'Kamanzi',      'emmanuel.kamanzi@auca.ac.rw',   3, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1011, 'Diane',    'Mutesi',       'diane.mutesi@auca.ac.rw',       1, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1012, 'Samuel',   'Gasana',       'samuel.gasana@auca.ac.rw',      3, 'SUSPENDED');

-- ---------- Courses ----------
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (101, 'INSY8311', 'Database Development with PL/SQL', 3, 1, 30);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (102, 'INSY8312', 'Systems Analysis and Design',      3, 1, 30);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (103, 'BUS1101',  'Principles of Management',         3, 2, 40);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (104, 'BUS2203',  'Financial Accounting',             4, 2, 40);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (105, 'SWE3301',  'Software Testing',                 3, 3, 25);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (106, 'SWE3302',  'Web Development',                  4, 3, 25);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (107, 'INSY9001', 'Advanced Seminar',                 2, 1,  3);
INSERT INTO courses (course_id, course_code, title, credits, dept_id, max_capacity) VALUES (108, 'BUS3305',  'Marketing Research',               3, 2, 35);

-- ---------- Enrollments, semester 2026-A (graded) ----------
-- Course 101 : Database Development with PL/SQL
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1001, 101, '2026-A', 92, 'A');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1002, 101, '2026-A', 78, 'C');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1003, 101, '2026-A', 85, 'B');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1004, 101, '2026-A', 66, 'D');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1007, 101, '2026-A', 88, 'B');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1011, 101, '2026-A', 95, 'A');
-- Course 102 : Systems Analysis and Design
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1001, 102, '2026-A', 81, 'B');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1004, 102, '2026-A', 59, 'F');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1007, 102, '2026-A', 73, 'C');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1011, 102, '2026-A', 90, 'A');
-- Course 103 : Principles of Management
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1002, 103, '2026-A', 55, 'F');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1003, 103, '2026-A', 70, 'C');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1006, 103, '2026-A', 84, 'B');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1009, 103, '2026-A', 91, 'A');
-- Course 104 : Financial Accounting
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1003, 104, '2026-A', 89, 'B');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1006, 104, '2026-A', 77, 'C');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1009, 104, '2026-A', 68, 'D');
-- Course 106 : Web Development
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1005, 106, '2026-A', 79, 'C');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1008, 106, '2026-A', 86, 'B');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1010, 106, '2026-A', 93, 'A');

-- ---------- Enrollments with marks but NO grade yet (course 105) ----------
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1002, 105, '2026-A', 60, NULL);
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1005, 105, '2026-A', 74, NULL);
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1008, 105, '2026-A', 82, NULL);
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester, marks, grade) VALUES (seq_enrollment.NEXTVAL, 1010, 105, '2026-A', 91, NULL);

-- ---------- Course 107 (capacity 3) - full, no marks yet ----------
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester) VALUES (seq_enrollment.NEXTVAL, 1001, 107, '2026-A');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester) VALUES (seq_enrollment.NEXTVAL, 1007, 107, '2026-A');
INSERT INTO enrollments (enrollment_id, student_id, course_id, semester) VALUES (seq_enrollment.NEXTVAL, 1011, 107, '2026-A');

COMMIT;

PROMPT === Sample data inserted ===
SELECT 'DEPARTMENTS' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'STUDENTS',    COUNT(*) FROM students
UNION ALL SELECT 'COURSES',     COUNT(*) FROM courses
UNION ALL SELECT 'ENROLLMENTS', COUNT(*) FROM enrollments;
