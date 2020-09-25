/*
  1) Build a query to count the number of loans per customer.
*/

SELECT custid, count(*) as loan_count
FROM all_loans
GROUP BY custid

/*
  2) Write a query to identify if a customer had more than one active loan at
    the same time.
*/

-- Returns all unique custid's that had more than 1 active loan at the same time
SELECT distinct a.custid
FROM all_loans a
JOIN all_loans b
  ON a.custid = b.custid
  AND a.loanid <> b.loanid
  AND (a.approvedate between b.approvedate and b.payoffdate OR
       a.approvedate between b.approvedate and b.writeoffdate)

/*
  3)  Write a query to pull loanid, custid, first name, last name, and loan
    amount from all_loans where the approvedate is after Jan 1, 2019, the state
    of the loan is in CA, the first name of the customer is either Matt, Kyle,
    Jessica or Mary and the last name of the customer starts with the
    letter 'Y'.
*/
SELECT loanid, custid, first_name, last_name, amount
FROM all_loans
WHERE approvedate > '2019-01-01'
  AND state = 'CA'
  AND last_name like 'Y%'

/*
  4) Write a query to calculate how much payment is received from each customer
    in the first 6 months of them being a customer (only include payments for
    the first loan).
*/

-- Capture the earliest loan start date for each customer
with earliest_date as (
  SELECT custid, MIN(approvedate) as earliest_loan_date
  FROM all_loans
  GROUP BY custid
),
-- Capture the relevant details of each customer's earliest loan start date
-- This assumes that each customer has only 1 loan associated with the earliest
-- loan start date
  first_loan as (
    SELECT ED.custid, AL.loanid,
          ED.earliest_loan_date as loan_date,
          ALH.amount_paid
    FROM earliest_date ED
    JOIN all_loans AL
      ON ED.custid = AL.custid
      AND ED.earliest_loan_date = AL.approvedate
    JOIN all_loanhist ALH
      ON ALH.loanid = AL.loanid
    WHERE DATEDIFF(month, ED.earliest_loan_date, ALH.snapshot_date) <= 6
  ),
SELECT custid, SUM(amount_paid)
FROM first_loan

/*
  5) Write a query to show the total % of principal collected as a percentage
    of the total loan amount in the first 6 months for each customer
    (if a customer has multiple loans, include all loans approved within
    6 months of the customer's first loan)
*/

-- Capture the earliest loan start date for each customer, as well as 6 months after that loan start date
with earliest_date as (
  SELECT custid,
    MIN(approvedate) as earliest_loan_date,
    DATEADD(month, 6, MIN(approvedate)) as six_month_date
  FROM all_loans
  GROUP BY custid
),
-- Capture all principal_paid amounts and all loan lended amounts from loans that lie within the 6 month window
six_month_window
 as (
  SELECT ED.custid,
        AL.loanid,
        AL.amount as total_loan_amount,
        ED.earliest_loan_date,
        ALH.principal_paid
  FROM earliest_date ED
  JOIN all_loans AL
    ON ED.custid = AL.custid
    AND AL.approvedate between ED.earliest_loan_date and ED.six_month_date
  JOIN all_loanhist ALH
    ON ALH.loanid = AL.loanid
    AND ALH.snapshot_date between ED.earliest_loan_date and ED.six_month_date
  WHERE DATEDIFF(month, ED.earliest_loan_date, ALH.snapshot_date) <= 6
),
SELECT custid,
  (SUM(principal_paid)/MAX(total_loan_amount))*100 as Perc_Principal_Paid
FROM six_month_window
GROUP BY custid
