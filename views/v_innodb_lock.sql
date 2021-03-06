#
# Name: v$innodb_only_lock_trx_id
# Author: YJ
# Date: 2016.06.27
# 설명: 가장 뿌리가 되는 lock 정보만 갖는 뷰
#       sys.`v$innodb_lock`를 사용할 수 있도록 하기 위해 먼저 만드는 뷰
# 
CREATE OR REPLACE
ALGORITHM=TEMPTABLE
DEFINER = 'root'@'localhost'
SQL SECURITY INVOKER
VIEW sys.`v$innodb_only_lock_trx_id`
AS
SELECT DISTINCT hold.blocking_trx_id AS hold_trx_id
               ,NULL                 AS wait_trx_id
               ,hold.blocking_trx_id AS trx_id
  FROM (information_schema.innodb_lock_waits hold LEFT JOIN
        information_schema.innodb_lock_waits wait
        ON((hold.blocking_trx_id = wait.requesting_trx_id)))
 WHERE isnull(wait.requesting_trx_id)
UNION ALL
SELECT hold.blocking_trx_id   AS hold_trx_id
      ,hold.requesting_trx_id AS wait_trx_id
      ,hold.requesting_trx_id AS trx_id
  FROM (information_schema.innodb_lock_waits hold LEFT JOIN
        information_schema.innodb_lock_waits wait
        ON((hold.blocking_trx_id = wait.requesting_trx_id)))
 WHERE isnull(wait.requesting_trx_id)
;

#
# Name: v$innodb_lock
# Author: YJ
# Date: 2016.06.27
# 선수조건: sys.`v$innodb_only_lock_trx_id` 뷰를 먼저 만든 후에 sys.`v$innodb_lock`를 생성해야 함
# 설명: row level lock 현황 조회
# 
DROP VIEW IF EXISTS sys.`v$innodb_lock`;

CREATE 
ALGORITHM=UNDEFINED
SQL SECURITY INVOKER
VIEW sys.`v$innodb_lock`
AS
SELECT concat(CASE
                WHEN locks.wait_trx_id IS NOT NULL THEN
                 '    '
                ELSE
                 ''
              END
             ,trx.trx_mysql_thread_id) AS thread_id
      #,trx.trx_id
      ,ps.command as thread_status
      ,trx.trx_state
      ,trx.trx_started
      ,trx.trx_wait_started
      ,timestampdiff(SECOND, trx.trx_wait_started, now()) as wait_secs
      ,concat(locks.lock_mode, ' (', locks.lock_type, ')' ) as lock_type
      ,locks.lock_table
      ,locks.lock_index
      ,trx.trx_query
      ,trx.trx_operation_state
      ,trx.trx_rows_locked as waiting_trx_rows_locked
      ,trx.trx_rows_modified AS waiting_trx_rows_modified
      ,trx.trx_lock_memory_bytes
      ,concat('KILL ', trx.trx_mysql_thread_id) as kill_thread
  FROM sys.`v$innodb_only_lock_trx_id` locks
  JOIN information_schema.innodb_trx trx
    ON locks.trx_id = trx.trx_id
  JOIN information_schema.processlist ps
    ON trx.trx_mysql_thread_id = ps.id
  LEFT JOIN information_schema.innodb_locks locks
    ON trx.trx_id = locks.lock_trx_id
 ORDER BY hold_trx_id, wait_trx_id
;
