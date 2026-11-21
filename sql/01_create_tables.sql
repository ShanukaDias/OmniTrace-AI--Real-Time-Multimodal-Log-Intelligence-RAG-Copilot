CREATE DATABASE IF NOT EXISTS OMNITRACE_DB;
CREATE SCHEMA IF NOT EXISTS OMNITRACE_DB.PUBLIC;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
  WAREHOUSE_SIZE = 'X-SMALL' 
  AUTO_SUSPEND = 300 
  AUTO_RESUME = TRUE;

USE DATABASE OMNITRACE_DB;
USE SCHEMA PUBLIC;
USE WAREHOUSE COMPUTE_WH;

-- Table for raw log text data
CREATE OR REPLACE TABLE RAW_LOGS_TEXT (
    raw_text STRING,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Table for parsed log records
CREATE OR REPLACE TABLE PARSED_LOGS (
    log_id STRING,
    timestamp TIMESTAMP_NTZ,
    service_name STRING,
    severity STRING,
    message STRING
);

-- Table to store vectors (using ARRAY to hold local embeddings safely)
CREATE OR REPLACE TABLE LOG_EMBEDDINGS_FREE (
    log_id STRING,
    message STRING,
    embedding ARRAY
);

-- Insert sample logs
INSERT INTO RAW_LOGS_TEXT (raw_text) VALUES
('{ "timestamp": "2026-10-28T02:14:00Z", "service": "payment-gateway", "severity": "ERROR", "message": "Connection timeout while communicating with Stripe API endpoint." }'),
('{ "timestamp": "2026-10-28T02:15:30Z", "service": "auth-service", "severity": "WARN", "message": "High token generation latency detected on Redis cluster node 3." }'),
('{ "timestamp": "2026-10-28T02:20:10Z", "service": "payment-gateway", "severity": "ERROR", "message": "Transaction declined: Insufficient funds for account ID #94821." }'),
('{ "timestamp": "2026-10-28T02:25:00Z", "service": "inventory-api", "severity": "INFO", "message": "Stock sync completed successfully with 4,210 items updated." }');

-- Parse JSON data into the structured table
INSERT INTO PARSED_LOGS (log_id, timestamp, service_name, severity, message)
SELECT 
    UUID_STRING() AS log_id,
    CAST(PARSE_JSON(raw_text):timestamp::STRING AS TIMESTAMP_NTZ) AS timestamp,
    PARSE_JSON(raw_text):service::STRING AS service_name,
    PARSE_JSON(raw_text):severity::STRING AS severity,
    PARSE_JSON(raw_text):message::STRING AS message
FROM RAW_LOGS_TEXT;
