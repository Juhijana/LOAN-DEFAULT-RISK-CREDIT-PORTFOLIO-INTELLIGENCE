CREATE DATABASE BankingRiskDB;
USE BankingRiskDB;

-- 1. Create Master Table: Customers / Borrowers
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    annual_income DECIMAL(12, 2) NOT NULL,
    home_ownership VARCHAR(20) NOT NULL,
    verification_status VARCHAR(50)
);

-- 2. Create Transaction Table: Loans
CREATE TABLE Loans (
    loan_id INT PRIMARY KEY,
    customer_id INT,
    loan_amount DECIMAL(12, 2) NOT NULL,
    term VARCHAR(20) NOT NULL,
    int_rate DECIMAL(6, 4) NOT NULL,
    installment DECIMAL(10, 2),
    issue_d VARCHAR(20),
    loan_status VARCHAR(30) NOT NULL,
    purpose VARCHAR(50),
    total_pymnt DECIMAL(12, 2),
    CONSTRAINT fk_customer
        FOREIGN KEY (customer_id) 
        REFERENCES Customers(customer_id)
        ON DELETE CASCADE
);

-- 3. Optimization Indexes for Joins and Filters
CREATE INDEX idx_loan_customer ON Loans(customer_id);
CREATE INDEX idx_loan_status ON Loans(loan_status);


SELECT COUNT(*) FROM bankingriskdb.loan_transactions;


SELECT 
    c.id AS customer_id,
    c.annual_inc AS annual_income,
    c.home_ownership,
    COUNT(l.id) AS total_loans_taken,
    COALESCE(SUM(l.loan_amnt), 0.00) AS total_borrowed_exposure,
    CASE 
        WHEN COUNT(l.id) = 0 THEN 'Potential Marketing Lead'
        ELSE 'Active Borrower'
    END AS customer_segment
FROM (
    -- Simulates customer master registry
    SELECT DISTINCT id, annual_inc, home_ownership 
    FROM bankingriskdb.loan_transactions
) c
LEFT JOIN bankingriskdb.loan_transactions l 
    ON c.id = l.id
GROUP BY 
    c.id, 
    c.annual_inc, 
    c.home_ownership
ORDER BY total_borrowed_exposure DESC
LIMIT 20;


SELECT 
    purpose,
    COUNT(id) AS total_loans_issued,
    CONCAT('$', FORMAT(SUM(loan_amnt), 2)) AS total_funded_capital,
    CONCAT(ROUND(AVG(CAST(REPLACE(int_rate, '%', '') AS DECIMAL(6,2))), 2), '%') AS avg_interest_rate,
    SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) AS defaulted_loans_count,
    ROUND((SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) * 100.0) / COUNT(id), 2) AS default_rate_pct,
    CONCAT('$', FORMAT(SUM(CASE WHEN loan_status = 'Charged Off' THEN (loan_amnt - total_pymnt) ELSE 0 END), 2)) AS net_unrecovered_loss
FROM bankingriskdb.loan_transactions
GROUP BY purpose
HAVING COUNT(id) > 5
ORDER BY default_rate_pct DESC;

SELECT 
    id AS loan_id,
    loan_amnt,
    int_rate,
    term,
    purpose,
    annual_inc,
    loan_status
FROM bankingriskdb.loan_transactions
WHERE loan_status = 'Charged Off'
  AND loan_amnt > (
      SELECT AVG(loan_amnt) 
      FROM bankingriskdb.loan_transactions
  )
ORDER BY loan_amnt DESC
LIMIT 20;


-- Prime Low-Risk Borrowers
SELECT 
    id AS borrower_id, 
    annual_inc, 
    loan_amnt, 
    'Low Risk Prime' AS risk_category
FROM bankingriskdb.loan_transactions
WHERE loan_status = 'Fully Paid' 
  AND annual_inc >= 75000

UNION

-- High-Risk Distressed Borrowers
SELECT 
    id AS borrower_id, 
    annual_inc, 
    loan_amnt, 
    'High Risk Distressed' AS risk_category
FROM bankingriskdb.loan_transactions
WHERE loan_status = 'Charged Off'
LIMIT 15;