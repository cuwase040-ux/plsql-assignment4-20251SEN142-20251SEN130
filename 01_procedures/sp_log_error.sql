-- =====================================================================
-- sp_log_error
-- Central error logger used by every other procedure for UNEXPECTED errors.
-- PRAGMA AUTONOMOUS_TRANSACTION: the log row is committed independently,
-- so it survives even when the caller rolls back its own transaction.
-- =====================================================================
CREATE OR REPLACE PROCEDURE sp_log_error (
  p_module  IN error_log.module_name%TYPE,
  p_code    IN error_log.error_code%TYPE,
  p_message IN error_log.error_message%TYPE
)
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO error_log (log_id, module_name, error_code, error_message)
  VALUES (seq_error_log.NEXTVAL, p_module, p_code, SUBSTR(p_message, 1, 4000));
  COMMIT;
END sp_log_error;
/
SHOW ERRORS
