-- Подключение в DBeaver: New Connection → DuckDB → in-memory

DROP TABLE IF EXISTS telco;

-- загрузка CSV
CREATE TABLE telco AS
SELECT * FROM './Telco-Customer-Churn.csv';

-- кол-во строк
SELECT COUNT(*) AS customers_cnt FROM telco;

-- Результат:
-- customers_cnt|
-- -------------+
--          7043|

DESCRIBE telco;

-- Результат:
-- column_name     |column_type|null|key|default|extra|
-- ----------------+-----------+----+---+-------+-----+
-- customerID      |VARCHAR    |YES |   |       |     |
-- gender          |VARCHAR    |YES |   |       |     |
-- SeniorCitizen   |BIGINT     |YES |   |       |     |
-- Partner         |BOOLEAN    |YES |   |       |     |
-- Dependents      |BOOLEAN    |YES |   |       |     |
-- tenure          |BIGINT     |YES |   |       |     |
-- PhoneService    |BOOLEAN    |YES |   |       |     |
-- MultipleLines   |VARCHAR    |YES |   |       |     |
-- InternetService |VARCHAR    |YES |   |       |     |
-- OnlineSecurity  |VARCHAR    |YES |   |       |     |
-- OnlineBackup    |VARCHAR    |YES |   |       |     |
-- DeviceProtection|VARCHAR    |YES |   |       |     |
-- TechSupport     |VARCHAR    |YES |   |       |     |
-- StreamingTV     |VARCHAR    |YES |   |       |     |
-- StreamingMovies |VARCHAR    |YES |   |       |     |
-- Contract        |VARCHAR    |YES |   |       |     |
-- PaperlessBilling|BOOLEAN    |YES |   |       |     |
-- PaymentMethod   |VARCHAR    |YES |   |       |     |
-- MonthlyCharges  |DOUBLE     |YES |   |       |     |
-- TotalCharges    |VARCHAR    |YES |   |       |     |
-- Churn           |BOOLEAN    |YES |   |       |     |


-- ****************************************************************************
-- ЗАПРОС 2 (тип 2): Агрегаты с GROUP BY
-- ****************************************************************************
-- Цель: Для каждого сочетания (has_partner, has_dependents) посчитать количество клиентов, 
-- средний monthly_charges, средний tenure_months и долю churn (я посчитала долю в процентах)

-- запрос из queries.sql

-- SELECT has_partner,
--        has_dependents,
--        COUNT(*) AS clients_cnt, 
--        ROUND(AVG(monthly_charges), 2) AS avg_monthly, 
--        ROUND(AVG(tenure_months), 2) AS avg_tenure,
--        ROUND(100.0 * SUM(CASE WHEN has_churned THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_pct
-- FROM customers
-- GROUP BY (has_partner, has_dependents)
-- ORDER BY churn_pct DESC;

-- запрос DuckDB
SELECT Partner AS has_partner,
       Dependents AS has_dependents,
       COUNT(*) AS clients_cnt,
       ROUND(AVG(MonthlyCharges), 2) AS avg_monthly,
       ROUND(AVG(tenure), 2) AS avg_tenure,
       ROUND(100.0 * SUM(CASE WHEN CHURN THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_pct
FROM telco
GROUP BY (has_partner, has_dependents)
ORDER BY churn_pct DESC;


-- Результат:
-- has_partner|has_dependents|clients_cnt|avg_monthly|avg_tenure|churn_pct|
-- -----------+--------------+-----------+-----------+----------+---------+
-- false      |false         |       3280|      62.98|      23.3|     34.2|
-- true       |false         |       1653|      74.98|     42.71|     25.4|
-- false      |true          |        361|      52.51|     23.85|     21.3|
-- true       |true          |       1749|      60.97|     41.36|     14.2|

-- Для сравнения результат того же запроса из queries.sql:
-- has_partner|has_dependents|clients_cnt|avg_monthly|avg_tenure|churn_pct|
-- -----------+--------------+-----------+-----------+----------+---------+
-- false      |false         |       3280|      62.98|     23.30|     34.2|
-- true       |false         |       1653|      74.98|     42.71|     25.4|
-- false      |true          |        361|      52.51|     23.85|     21.3|
-- true       |true          |       1749|      60.97|     41.36|     14.2|

-- Результат одинаковый, единственное отличие в представлении числовых данных
-- (avg_tenure в части Б с дополнительным нулем на конце)


-- ****************************************************************************
-- ЗАПРОС 5 (тип 5): Изменение данных/схемы (UPDATE с CASE + ALTER TABLE + транзакция)
-- ****************************************************************************
-- Цель: Добавить колонку is_family через ALTER TABLE и заполнить через UPDATE ... CASE
-- в транзакции с откатом
-- Операторы: UPDATE, CASE/WHEN, ALTER TABLE, ADD COLUMN, BEGIN/ROLLBACK, SET

-- будем считать, что is_family говорит о наличии хотя бы одного (либо partner, либо dependent)

-- запрос из queries.sql

-- BEGIN;
-- ALTER TABLE customers ADD COLUMN is_family BOOLEAN;
-- UPDATE customers
-- SET is_family = CASE
--     WHEN NOT has_partner AND NOT has_dependents THEN false
--     ELSE true
-- END;
-- -- проверяем изменения
-- SELECT is_family, COUNT(*) AS clients_cnt 
-- FROM customers 
-- GROUP BY is_family;
-- ROLLBACK;

-- запрос DuckDB
BEGIN;
ALTER TABLE telco ADD COLUMN is_family BOOLEAN;
UPDATE telco
SET is_family = CASE
    WHEN NOT Partner AND NOT Dependents THEN false
    ELSE true
END;
-- проверяем изменения
SELECT is_family, COUNT(*) AS clients_cnt 
FROM telco 
GROUP BY is_family;
ROLLBACK;

-- Результат проверки изменений:
-- is_family|clients_cnt|
-- ---------+-----------+
-- false    |       3280|
-- true     |       3763|


-- Результат проверки изменений из queries.sql:
-- is_family|clients_cnt|
-- ---------+-----------+
-- false    |       3280|
-- true     |       3763|

-- Результат идентичный

-- В приведенных выше двух запросах синтаксис SQL одинаковый, в запросах
-- отличаются только названия таблиц и атрибутов, к которым обращаемся