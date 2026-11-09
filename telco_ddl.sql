
-- DDL-скрипт схемы PostgreSQL
-- ============================================================================
-- ИДЕМПОТЕНТНОСТЬ: скрипт можно запускать повторно без ошибок.
-- ЗАПУСК:
--   DBeaver: SQL Editor -> Execute Script (Alt+X)
--   psql:    psql -h localhost -U postgres -d telco -f telco_ddl.sql
-- ============================================================================

-- ****************************************************************************
-- 0. Чистка предыдущего состояния (идемпотентность)
-- ****************************************************************************

DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS contract_types CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS internet_services CASCADE;

-- ****************************************************************************
-- 1. Таблицы-словари (минимум 3)
-- ****************************************************************************

-- 1.1. Типы контрактов
CREATE TABLE contract_types (
    contract_type_id   SMALLINT PRIMARY KEY,
    contract_type_name VARCHAR(20) NOT NULL UNIQUE,
    description        TEXT NOT NULL,
    CHECK (contract_type_name in ('Month-to-month', 'One year', 'Two year'))
);

COMMENT ON TABLE contract_types IS
    'Справочник типов контрактов: помесячный, годовой, двухлетний';

INSERT INTO contract_types (contract_type_id, contract_type_name, description) VALUES
    (1, 'Month-to-month', 'Помесячный контракт'),
    (2, 'One year', 'Годовой контракт'),
    (3, 'Two year', 'Двухлетний контракт');

-- 1.2. Методы оплаты
CREATE TABLE payment_methods (
    payment_method_id   SMALLINT PRIMARY KEY,
    payment_method_name VARCHAR(30) NOT NULL UNIQUE,
    description         TEXT NOT NULL,
    CHECK (payment_method_name in ('Electronic check', 'Mailed check', 'Bank transfer (automatic)',
                                   'Credit card (automatic)')) 
);

COMMENT ON TABLE payment_methods IS
    'Справочник способов оплаты: электронный чек, чек по почте, банковский перевод (автоматически),
     кредитная карта (автоматически)';

INSERT INTO payment_methods (payment_method_id, payment_method_name, description) VALUES
    (1, 'Electronic check', 'Электронный чек'),
    (2, 'Mailed check', 'Чек по почте'),
    (3, 'Bank transfer (automatic)', 'Банковский перевод (автоматически)'),
    (4, 'Credit card (automatic)', 'Кредитная карта (автоматически)');

-- 1.3. Типы интернет-сервисов
CREATE TABLE internet_services (
    internet_service_id   SMALLINT PRIMARY KEY,
    internet_service_name VARCHAR(20) NOT NULL UNIQUE,
    description           TEXT NOT NULL,

    CHECK (internet_service_name in ('DSL', 'Fiber optic', 'No')),
    -- проверка, что значению нет интернет сервиса соответствует только internet_service_id = 3
    -- (нужна для проверки в customers)
    CHECK ((internet_service_id = 3 AND internet_service_name = 'No') OR 
           (internet_service_id <> 3 AND internet_service_name <> 'No'))
);

COMMENT ON TABLE internet_services IS
    'Справочник типов интернет сервисов: цифровая абонентская линия, оптоволокно, нет интернет сервиса';

INSERT INTO internet_services (internet_service_id, internet_service_name, description) VALUES
    (1, 'DSL', 'Цифровая абонентская линия'),
    (2, 'Fiber optic', 'Оптоволокно'),
    (3, 'No', 'Нет интернет сервиса');

COMMENT ON COLUMN internet_services.internet_service_id IS
    'Фиксируем, что internet_service_id = 3 означает отсутствие интернет-сервисов';


-- ****************************************************************************
-- 2. Основная таблица customers
-- ****************************************************************************

CREATE TABLE customers (
    customer_id             VARCHAR(10) PRIMARY KEY,
    gender                  VARCHAR(10) NOT NULL CHECK (gender in ('Male', 'Female')),
    is_senior               BOOLEAN NOT NULL,
    has_partner             BOOLEAN NOT NULL,
    has_dependents          BOOLEAN NOT NULL,
    tenure_months           INTEGER NOT NULL CHECK (tenure_months >= 0),
    monthly_charges         NUMERIC(5,2) NOT NULL CHECK (monthly_charges > 0),
    total_charges           NUMERIC(6,2) CHECK (total_charges > 0),  -- допускаем NULL для tenure=0
    has_phone_service       BOOLEAN NOT NULL,
    has_multiple_lines      BOOLEAN, -- допускаем NULL для No phone service
    internet_service_id     SMALLINT NOT NULL
        REFERENCES internet_services(internet_service_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    has_online_security     BOOLEAN, -- допускаем NULL для No internet service
    has_online_backup       BOOLEAN, -- допускаем NULL для No internet service
    has_device_protection   BOOLEAN, -- допускаем NULL для No internet service
    has_tech_support        BOOLEAN, -- допускаем NULL для No internet service
    has_streaming_tv        BOOLEAN, -- допускаем NULL для No internet service
    has_streaming_movies    BOOLEAN, -- допускаем NULL для No internet service
    contract_type_id        SMALLINT NOT NULL
        REFERENCES contract_types(contract_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    has_paperless_billing   BOOLEAN NOT NULL,
    payment_method_id       SMALLINT NOT NULL
        REFERENCES payment_methods(payment_method_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    has_churned             BOOLEAN NOT NULL,

    -- проверяем, что total_charges NULL <=> tenure_months = 0
    CHECK ((tenure_months = 0 AND total_charges IS NULL) OR
           (tenure_months <> 0 AND total_charges IS NOT NULL)),

    -- проверяем, что клиенты без телефенного сервиса не имеют несколько линий
    CHECK ((has_phone_service AND has_multiple_lines IS NOT NULL) OR 
            (NOT has_phone_service AND has_multiple_lines IS NULL)),

    -- проверяем, что все 6 опций отсутствуют <=> когда нет интернет сервиса
    CHECK ((internet_service_id = 3 AND has_online_security IS NULL AND
            has_online_backup IS NULL AND has_device_protection IS NULL AND 
            has_tech_support IS NULL AND has_streaming_tv IS NULL AND
            has_streaming_movies IS NULL) OR (internet_service_id <> 3 AND 
            has_online_security IS NOT NULL AND has_online_backup IS NOT NULL
            AND has_device_protection IS NOT NULL AND has_tech_support IS NOT NULL 
            AND has_streaming_tv IS NOT NULL AND has_streaming_movies IS NOT NULL))   
);

COMMENT ON TABLE customers IS
    'Основная таблица клиентов телеком-компании. Одна строка = один клиент.';

COMMENT ON COLUMN customers.tenure_months IS
    'Длительность обслуживания в месяцах; CHECK >= 0';
COMMENT ON COLUMN customers.total_charges IS
    'Суммарные начисления за всё время; допускается NULL, NULL <=> когда tenure_months = 0';
COMMENT ON COLUMN customers.monthly_charges IS
    'Ежемесячные начисления; CHECK > 0';

COMMENT ON COLUMN customers.customer_id IS
    'PK, уникальный id клиента, состоит из 10 символов: 4 цифры-5 букв';
COMMENT ON COLUMN customers.gender IS
    'Пол клиента, может принимать только 2 значения: Male или Female';
COMMENT ON COLUMN customers.is_senior IS
    'Булевый признак, который показывает является ли клиент пожилым';
COMMENT ON COLUMN customers.has_partner IS
    'Булевый признак, который показывает есть ли у клиента партнер';
COMMENT ON COLUMN customers.has_dependents IS
    'Булевый признак, который показывает есть ли иждевенцы, которые находятся на содержании у клиента';

COMMENT ON COLUMN customers.has_phone_service IS
    'Булевый признак, который показывает есть ли у клиента телефонные сервисы';
COMMENT ON COLUMN customers.has_multiple_lines IS
    'Булевый признак, который показывает есть ли у клиента несколько телефонных линий; допускается NULL,
     NULL <=> когда has_phone_service = False';

COMMENT ON COLUMN customers.internet_service_id IS
    'FK, ссылается на словарь internet_services';
COMMENT ON COLUMN customers.contract_type_id IS
    'FK, ссылается на словарь contract_types';
COMMENT ON COLUMN customers.payment_method_id IS
    'FK, ссылается на словарь payment_methods';

COMMENT ON COLUMN customers.has_online_security IS
    'Булевый признак, который показывает подключена ли у клиента услуга онлайн защиты; допускается NULL,
     NULL <=> когда internet_service_id = 3 (интернет сервисов нет)';
COMMENT ON COLUMN customers.has_online_backup IS
    'Булевый признак, который показывает подключена ли у клиента услуга резервного копирования данных
     онлайн; допускается NULL, NULL <=> когда internet_service_id = 3 (интернет сервисов нет)';
COMMENT ON COLUMN customers.has_device_protection IS
    'Булевый признак, который показывает подключена ли у клиента услуга защиты устройств;  допускается NULL,
     NULL <=> когда internet_service_id = 3 (интернет сервисов нет)';
COMMENT ON COLUMN customers.has_tech_support IS
    'Булевый признак, который показывает подключена ли у клиента услуга технической поддержки; допускается NULL,
     NULL <=> когда internet_service_id = 3 (интернет сервисов нет)';
COMMENT ON COLUMN customers.has_streaming_tv IS
    'Булевый признак, который показывает подключена ли у клиента услуга тв стриминга; допускается NULL,
     NULL <=> когда internet_service_id = 3 (интернет сервисов нет)';
COMMENT ON COLUMN customers.has_streaming_movies IS
    'Булевый признак, который показывает подключена ли у клиента услуга стриминга фильмов; допускается NULL,
     NULL <=> когда internet_service_id = 3 (интернет сервисов нет)';

COMMENT ON COLUMN customers.has_paperless_billing IS
    'Булевый признак, который показывает наличие электронного выставления счетов';
COMMENT ON COLUMN customers.has_churned IS
    'Булевый признак, который показывает ушел ли клиент за последний месяц';


-- ****************************************************************************
-- 3. Проверка идемпотентности: запустить скрипт повторно — должно пройти без ошибок
-- ****************************************************************************

SELECT 'DDL-script executed successfully' AS status;
SELECT 'contract_types: ' || COUNT(*) FROM contract_types;
SELECT 'customers: ' || COUNT(*) FROM customers;  -- 0 до импорта CSV
SELECT * FROM customers LIMIT 5;