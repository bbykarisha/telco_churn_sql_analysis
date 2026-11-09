-- ****************************************************************************
-- ЗАПРОС 1 (тип 1): Информационная схема: мощность и степень отношений
-- ****************************************************************************
-- Цель: Посчитать количество строк во всех таблицах схемы + степень таблицы customers
-- Операторы: information_schema, COUNT(*), UNION ALL


SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'contract_types', COUNT(*) FROM contract_types
UNION ALL SELECT 'payment_methods', COUNT(*) FROM payment_methods
UNION ALL SELECT 'internet_services', COUNT(*) FROM internet_services;

-- Результат:
-- tbl              | row_count
-- -----------------+----------
-- customers        | 7043
-- contract_types   | 3
-- payment_methods  | 4
-- internet_services| 3

SELECT COUNT(*) AS customers_degree FROM information_schema.columns
WHERE table_schema = 'telco_churn' AND table_name = 'customers';

-- Результат:
-- customers_degree|
-- ----------------+
--               21|

-- Интерпретация: схема состоит из 4 таблиц. Основная таблица содержит 7043 клиента,
-- словари компактны (3-4 значения), степень таблицы customers = 21.


-- ****************************************************************************
-- ЗАПРОС 2 (тип 2): Агрегаты с GROUP BY
-- ****************************************************************************
-- Цель: Для каждого сочетания (has_partner, has_dependents) посчитать количество клиентов, 
-- средний monthly_charges, средний tenure_months и долю churn (я посчитала долю в процентах)

-- Операторы: SUM/AVG/COUNT, GROUP BY, CASE WHEN/THEN/ELSE, ROUND, ORDER BY

SELECT has_partner,
       has_dependents,
       COUNT(*) AS clients_cnt, 
       ROUND(AVG(monthly_charges), 2) AS avg_monthly, 
       ROUND(AVG(tenure_months), 2) AS avg_tenure,
       ROUND(100.0 * SUM(CASE WHEN has_churned THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_pct
FROM customers
GROUP BY (has_partner, has_dependents)
ORDER BY churn_pct DESC;

-- Результат:
-- has_partner|has_dependents|clients_cnt|avg_monthly|avg_tenure|churn_pct|
-- -----------+--------------+-----------+-----------+----------+---------+
-- false      |false         |       3280|      62.98|     23.30|     34.2|
-- true       |false         |       1653|      74.98|     42.71|     25.4|
-- false      |true          |        361|      52.51|     23.85|     21.3|
-- true       |true          |       1749|      60.97|     41.36|     14.2|

-- Интерпретация: больше всего доля ушедших клиентов тогда, когда у клиента 
-- нет партнера и иждивенцев, она составляет 34.2%, меньше всего -- когда, 
-- наоборот, есть партнер и иждивенцы, тут доля ухода уже = 14.2%.


-- ****************************************************************************
-- ЗАПРОС 3 (тип 3): Агрегат -> новое отношение (CTAS или VIEW)
-- ****************************************************************************
-- Цель: Создать витрину vit_family_churn: агрегат по семейному статусу (полная 
-- семья / только партнёр / только иждивенцы / одинокий)

-- Операторы: CREATE VIEW, SUM/AVG/COUNT, GROUP BY, CASE WHEN/THEN/ELSE, ROUND, ORDER BY

-- P.S. можно было использовать и CTAS, но я выбрала VIEW

DROP VIEW IF EXISTS vit_family_churn;

CREATE VIEW vit_family_churn AS
SELECT CASE WHEN has_partner AND has_dependents THEN 'полная семья'
            WHEN has_partner THEN 'только партнёр'
            WHEN has_dependents THEN 'только иждивенцы'
            ELSE 'одинокий'
       END AS fam_status,
       has_partner,
       has_dependents,
       COUNT(*) AS clients_cnt, 
       ROUND(AVG(monthly_charges), 2) AS avg_monthly, 
       ROUND(AVG(tenure_months), 2) AS avg_tenure,
       ROUND(100.0 * SUM(CASE WHEN has_churned THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_pct
FROM customers
GROUP BY (has_partner, has_dependents);

SELECT fam_status, clients_cnt, avg_monthly, avg_tenure, churn_pct 
FROM vit_family_churn
ORDER BY churn_pct DESC;

-- Результат:
-- fam_status      |clients_cnt|avg_monthly|avg_tenure|churn_pct|
-- ----------------+-----------+-----------+----------+---------+
-- одинокий        |       3280|      62.98|     23.30|     34.2|
-- только партнёр  |       1653|      74.98|     42.71|     25.4|
-- только иждивенцы|        361|      52.51|     23.85|     21.3|
-- полная семья    |       1749|      60.97|     41.36|     14.2|

-- Интерпретация: самая большая доля ушедших клиентов -- в категории "одинокие" (34.2%), 
-- клиенты из полной семьи имеют самую маленькую долю ухода, она составляет 14.2%.


-- ****************************************************************************
-- ЗАПРОС 4 (тип 4): WHERE с шаблонами (LIKE / ILIKE / regex / IN / BETWEEN)
-- ****************************************************************************
-- Цель: Семейные клиенты, у которых customer_id начинается на '10' и payment_method
-- содержит слово 'check' (регистронезависимо)

-- P.S. в коде ниже под семейными клиентами понимаются все, кроме одиноких, т.е. достаточно 
-- либо наличие партнера, либо -- иждивенца, либо -- и того, и того

-- Операторы: LIKE/ILIKE, IN, WHERE, ORDER BY, JOIN

-- вариант 1 (на основе того, что check используется в payment_method_id = 1 и 2)
SELECT customer_id, has_partner, has_dependents, payment_method_id
FROM customers
WHERE (has_partner OR has_dependents) AND (customer_id LIKE '10%') AND (payment_method_id IN (1, 2))
ORDER BY customer_id;

-- Результат (первые 5 строк):
-- customer_id|has_partner|has_dependents|payment_method_id|
-- -----------+-----------+--------------+-----------------+
-- 1013-QCWAM |true       |false         |                1|
-- 1015-JPFYW |false      |true          |                2|
-- 1020-JPQOW |true       |false         |                1|
-- 1024-GUALD |true       |false         |                1|
-- 1024-VRZHF |true       |false         |                1|

-- вариант 2 (с явной проверкой payment_method_name)
SELECT c.customer_id, c.has_partner, c.has_dependents, p.payment_method_name 
FROM customers c
    JOIN payment_methods p on c.payment_method_id = p.payment_method_id
    WHERE (c.has_partner OR c.has_dependents) AND (c.customer_id LIKE '10%') AND 
          (p.payment_method_name ILIKE '%check%')
ORDER BY c.customer_id;

-- Результат (первые 5 строк):
-- customer_id|has_partner|has_dependents|payment_method_name|
-- -----------+-----------+--------------+-------------------+
-- 1013-QCWAM |true       |false         |Electronic check   |
-- 1015-JPFYW |false      |true          |Mailed check       |
-- 1020-JPQOW |true       |false         |Electronic check   |
-- 1024-GUALD |true       |false         |Electronic check   |
-- 1024-VRZHF |true       |false         |Electronic check   |

-- Интерпретация: оба запроса дают одинаковый набор клиентов: семейных людей,
-- чей customer_id начинается на 10 и в payment_method встречается check (регистронезависимо)


-- ****************************************************************************
-- ЗАПРОС 5 (тип 5): Изменение данных/схемы (UPDATE с CASE + ALTER TABLE + транзакция)
-- ****************************************************************************
-- Цель: Добавить колонку is_family через ALTER TABLE и заполнить через UPDATE ... CASE
-- в транзакции с откатом
-- Операторы: UPDATE, CASE/WHEN, ALTER TABLE, ADD COLUMN, BEGIN/ROLLBACK, SET

-- будем считать, что is_family говорит о наличии хотя бы одного (либо partner, либо dependent)

BEGIN;
ALTER TABLE customers ADD COLUMN is_family BOOLEAN;
UPDATE customers
SET is_family = CASE
    WHEN NOT has_partner AND NOT has_dependents THEN false
    ELSE true
END;
-- проверяем изменения
SELECT is_family, COUNT(*) AS clients_cnt 
FROM customers 
GROUP BY is_family;
ROLLBACK;  -- безопасный откат учебных правок

-- Результат проверки изменений:
-- is_family|clients_cnt|
-- ---------+-----------+
-- false    |       3280|
-- true     |       3763|

-- Интерпретация: клиенты, у которых есть либо партнер, либо иждивенец, либо и тот, 
-- и тот, в данных преобладают, кол-во таких клиентов = 3763, в то время как кол-во 
-- одиноких клиентов = 3280.


-- ****************************************************************************
-- ЗАПРОС 6 (тип 6): Вложенные SELECT / коррелированные подзапросы
-- ****************************************************************************
-- Цель: Семейные клиенты с monthly_charges выше среднего по всем семейным
-- Операторы: CTE, WHERE, ORDER BY, AVG, CROSS JOIN

WITH family_stats AS (
    SELECT AVG(monthly_charges) AS avg_monthly
    FROM customers
    WHERE (has_partner OR has_dependents)
)
SELECT c.customer_id, c.monthly_charges
FROM customers c, family_stats f
WHERE (c.has_partner OR c.has_dependents) 
    AND (c.monthly_charges > f.avg_monthly)
ORDER BY c.monthly_charges;

-- Результат (первые 5 строк):
-- customer_id|monthly_charges|
-- -----------+---------------+
-- 1373-ORVIZ |          66.35|
-- 1697-NVVGY |          66.40|
-- 6507-DTJZV |          66.40|
-- 7036-ZZKBD |          66.40|
-- 9351-LZYGF |          66.40|

-- вывод по убыванию monthly_charges
WITH family_stats AS (
    SELECT AVG(monthly_charges) AS avg_monthly
    FROM customers
    WHERE (has_partner OR has_dependents)
)
SELECT c.customer_id, c.monthly_charges
FROM customers c, family_stats f
WHERE (c.has_partner OR c.has_dependents)
    AND (c.monthly_charges > f.avg_monthly)
ORDER BY c.monthly_charges DESC;

-- Результат (первые 5 строк):
-- customer_id|monthly_charges|
-- -----------+---------------+
-- 7569-NMZYQ |         118.75|
-- 5989-AXPUC |         118.60|
-- 2889-FPWRM |         117.80|
-- 3810-DVDQQ |         117.60|
-- 9739-JLPQJ |         117.50|

-- Интерпретация: минимальные ежемесячные начисления семейных клиентов, которые 
-- выше среднего по всем семейным клиентам = 66.35, максимальные -- 118.75


-- ****************************************************************************
-- ЗАПРОС 7 (тип 7): Запрос для R/Python-анализа (boxplot / корреляция / heatmap)
-- ****************************************************************************
-- Цель: Выборка для boxplot: family_status (4 категории) + monthly_charges + 
-- total_charges + tenure_months

-- Операторы: SELECT с нужными колонками, CASE/WHEN, ORDER BY

-- P.S. перед построением boxplotа нужно обработать NULL значения в total_charges
-- в R/Python

SELECT CASE WHEN has_partner AND has_dependents THEN 'полная семья'
            WHEN has_partner THEN 'только партнёр'
            WHEN has_dependents THEN 'только иждивенцы'
            ELSE 'одинокий'
       END AS family_status,
       monthly_charges, 
       total_charges, 
       tenure_months
FROM customers
ORDER BY family_status;

-- Результат:
-- family_status|monthly_charges|total_charges|tenure_months|
-- -------------+---------------+-------------+-------------+
-- одинокий     |          99.15|      3615.60|           36|
-- одинокий     |          48.80|      1536.75|           30|
-- одинокий     |          75.85|       724.65|            9|
-- одинокий     |          73.80|       704.30|            9|
-- одинокий     |          84.90|      3369.05|           40|

-- Интерпретация: подготовленная выборка позволит построить boxplot
-- для анализа распределения ежемесячных начислений, суммарных начислений 
-- и длительности обслуживания в месяцах по 4 категориям клиентов по семейному 
-- статусу. в выводе запроса каждая строка соответствует одному клиенту 


-- ****************************************************************************
-- ЗАПРОС 8 (тип 8): Простые JOIN (3+ таблицы)
-- ****************************************************************************
-- Цель: Семейные клиенты, ушедшие в churn: соединить customers + genders + 
-- + contract_types + payment_methods 

-- P.S. у меня нет отношения genders, вместо него добавила internet_services

-- Операторы: LEFT JOIN, WHERE, CASE/WHEN, ORDER BY, LIMIT

SELECT c.customer_id, c.gender,
       CASE WHEN c.has_partner AND c.has_dependents THEN 'полная семья'
            WHEN c.has_partner THEN 'только партнёр'
            WHEN c.has_dependents THEN 'только иждивенцы'
       END AS family_status,
       c.has_phone_service,
       i.description AS internet_service, 
       ct.description AS contract_type,
       p.description AS payment_method
FROM customers c
LEFT JOIN internet_services i ON i.internet_service_id = c.internet_service_id
LEFT JOIN contract_types ct ON ct.contract_type_id = c.contract_type_id
LEFT JOIN payment_methods p ON p.payment_method_id = c.payment_method_id
WHERE (c.has_partner OR c.has_dependents) AND c.has_churned
ORDER BY c.customer_id
LIMIT 7;

-- P.S. чтобы вывести всех клиентов достаточно убрать LIMIT 7

-- Результат:
-- customer_id|gender|family_status   |has_phone_service|internet_service          |contract_type      |payment_method                    |
-- -----------+------+----------------+-----------------+--------------------------+-------------------+----------------------------------+
-- 0011-IGKFF |Male  |только партнёр  |true             |Оптоволокно               |Помесячный контракт|Электронный чек                   |
-- 0013-EXCHZ |Female|только партнёр  |true             |Оптоволокно               |Помесячный контракт|Чек по почте                      |
-- 0023-XUOPT |Female|только партнёр  |true             |Оптоволокно               |Помесячный контракт|Электронный чек                   |
-- 0031-PVLZI |Female|полная семья    |true             |Нет интернет сервиса      |Помесячный контракт|Чек по почте                      |
-- 0032-PGELS |Female|полная семья    |false            |Цифровая абонентская линия|Помесячный контракт|Банковский перевод (автоматически)|
-- 0107-YHINA |Male  |только иждивенцы|true             |Оптоволокно               |Помесячный контракт|Электронный чек                   |
-- 0112-QWPNC |Male  |только партнёр  |true             |Цифровая абонентская линия|Годовой контракт   |Электронный чек                   |

-- Интерпретация: были отфильтрованы и выведены первые 7 семейных клиентов, которые ушли из 
-- телеком компании, по ним выведена основная информация: id, пол, семейный статус, наличие 
-- телефонного сервиса, тип интернет сервиса (или его отсутствие), тип контракта и способ оплаты


-- ****************************************************************************
-- ЗАПРОС 9 (тип 9): Сложные JOIN -> витрина -> экспорт в CSV
-- ****************************************************************************
-- Цель: Полная аналитика семейных клиентов: все словари + COPY TO CSV
-- Операторы: 4 таблицы, CREATE TABLE AS, COPY ... TO ... CSV HEADER,
--            LEFT JOIN, WHERE, ORDER BY

DROP TABLE IF EXISTS vit_family_customers_full;

CREATE TABLE vit_family_customers_full AS
SELECT c.customer_id,
       c.gender,
       c.is_senior,
       CASE WHEN c.has_partner AND c.has_dependents THEN 'полная семья'
            WHEN c.has_partner THEN 'только партнёр'
            WHEN c.has_dependents THEN 'только иждивенцы'
       END AS family_status,
       c.has_phone_service as phone_service,
       c.has_multiple_lines as multiple_lines,
       i.description AS internet_service,
       c.has_online_security as online_security,
       c.has_online_backup as online_backup,
       c.has_device_protection as device_protection,
       c.has_tech_support as tech_support,
       c.has_streaming_tv as streaming_tv,
       c.has_streaming_movies as streaming_movies,
       ct.description AS contract_type,
       c.has_paperless_billing AS paperless_billing,
       p.description AS payment_method,
       c.tenure_months, c.monthly_charges, c.total_charges,
       c.has_churned
FROM customers c
LEFT JOIN internet_services i ON i.internet_service_id = c.internet_service_id
LEFT JOIN contract_types ct ON ct.contract_type_id = c.contract_type_id
LEFT JOIN payment_methods p ON p.payment_method_id = c.payment_method_id
WHERE c.has_partner OR c.has_dependents;

-- проверяем, что все правильно
SELECT v.customer_id, v.gender, v.family_status,
       v.phone_service, v.multiple_lines,
       v.internet_service, v.contract_type, v.payment_method,
       v.has_churned 
FROM vit_family_customers_full v;

-- P.S. пустая строка в multiple_lines в текстовом виде это NULL значение (просто так отображается)

-- Результат (первые 5 строк):
-- customer_id|gender|family_status   |phone_service|multiple_lines|internet_service          |contract_type      |payment_method                    |has_churned|
-- -----------+------+----------------+-------------+--------------+--------------------------+-------------------+----------------------------------+-----------+
-- 7590-VHVEG |Female|только партнёр  |false        |              |Цифровая абонентская линия|Помесячный контракт|Электронный чек                   |false      |
-- 1452-KIOVK |Male  |только иждивенцы|true         |true          |Оптоволокно               |Помесячный контракт|Кредитная карта (автоматически)   |false      |
-- 7892-POOKP |Female|только партнёр  |true         |true          |Оптоволокно               |Помесячный контракт|Электронный чек                   |true       |
-- 6388-TABGU |Male  |только иждивенцы|true         |false         |Цифровая абонентская линия|Годовой контракт   |Банковский перевод (автоматически)|false      |
-- 9763-GRSKD |Male  |полная семья    |true         |false         |Цифровая абонентская линия|Помесячный контракт|Чек по почте                      |false      |

SELECT COUNT(*) AS fam_customers_cnt
FROM vit_family_customers_full;

-- Результат:
-- fam_customers_cnt|
-- -----------------+
--              3763|

-- Интерпретация: из всех 4 отношений создаем единую таблицу семейных клиентов, в ней 3763 строки

COPY vit_family_customers_full TO '/tmp/analytics_export.csv'
WITH (FORMAT csv, HEADER, ENCODING 'UTF8');

-- В DBeaver: используйте Export Data wizard вместо серверного COPY
