--A. Customer Nodes Exploration
--How many unique nodes are there on the Data Bank system?
SELECT
	COUNT(DISTINCT node_id) AS uni_nodes
FROM customer_nodes;

OUTPUT
"uni_nodes"
5

--What is the number of nodes per region?
SELECT
	r.region_name,
	COUNT(c.node_id)
FROM customer_nodes c INNER JOIN regions r
ON c.region_id=r.region_id
GROUP BY r.region_name;

OUTPUT
"region_name"	"count"
"America"	735
"Australia"	770
"Africa"	714
"Asia"	665
"Europe"	616

--How many customers are allocated to each region?
SELECT
	r.region_name,
	COUNT(DISTINCT c.customer_id) AS num_of_cust
FROM customer_nodes c INNER JOIN regions r
ON c.region_id=r.region_id
GROUP BY r.region_name;

OUTPUT
"region_name"	"num_of_cust"
"Africa"	102
"America"	105
"Asia"	95
"Australia"	110
"Europe"	88

--How many days on average are customers reallocated to a different node?
SELECT
	ROUND(AVG(end_date-start_date),0) AS average
FROM customer_nodes
WHERE end_date !='9999-12-31'

OUTPUT
"average"
15

--What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH days AS (
SELECT
	r.region_name,
	AGE(c.end_date,c.start_date) AS days
FROM customer_nodes c INNER JOIN regions r
ON c.region_id=r.region_id
WHERE c.end_date!='9999-12-31'
)
SELECT
	region_name,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY days) AS median,
	PERCENTILE_CONT(0.8) WITHIN GROUP(ORDER BY days) AS eighty_percentile,
	PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY days) AS nintyfive_percentile
FROM days
GROUP BY region_name;

OUTPUT
"region_name"	"median"	"eighty_percentile"	"nintyfive_percentile"
"Africa"	"15 days"	"24 days"	"28 days"
"America"	"15 days"	"23 days"	"28 days"
"Asia"	"15 days"	"23 days"	"28 days"
"Australia"	"15 days"	"23 days"	"28 days"
"Europe"	"15 days"	"24 days"	"28 days"

--B. Customer Transactions
--What is the unique count and total amount for each transaction type?
SELECT
	txn_type,
	COUNT(txn_type),
	SUM(txn_amount)
FROM customer_transactions
GROUP BY txn_type;

OUTPUT
"txn_type"	"count"	"sum"
"purchase"	1617	806537
"withdrawal"	1580	793003
"deposit"	2671	1359168

--What is the average total historical deposit counts and amounts for all customers?
SELECT
	txn_type,
	ROUND(COUNT(txn_type)::NUMERIC/COUNT(DISTINCT customer_id),3),
	ROUND(SUM(txn_amount)::NUMERIC/COUNT(DISTINCT customer_id),3)
FROM customer_transactions
WHERE txn_type LIKE 'dep%'
GROUP BY txn_type;

OUTPUT
"txn_type"	"round"	"round-2"
"deposit"	5.342	2718.336

--For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH tt AS (
SELECT
	TO_CHAR(txn_date,'YYYY-MM') AS months,	
	customer_id,
	COUNT(CASE WHEN txn_type LIKE 'dep%' THEN 1 ELSE 0 END) AS deposit,
	COUNT(CASE WHEN txn_type LIKE 'pur%' THEN 1 ELSE 0 END) AS purchase,
	COUNT(CASE WHEN txn_type LIKE 'with%' THEN 1 ELSE 0 END) AS withdrawal
FROM customer_transactions
GROUP BY months, customer_id
)
SELECT
	months,
	COUNT(CASE WHEN deposit>1 AND(purchase>0 OR withdrawal>0) THEN 1 ELSE 0 END) AS cust_dep_and_pur_or_with
FROM tt
GROUP BY months;

OUTPUT
"months"	"cust_dep_and_pur_or_with"
"2020-01"	500
"2020-04"	309
"2020-03"	456
"2020-02"	455

--What is the closing balance for each customer at the end of the month?
WITH tt AS (
SELECT
	customer_id,
	TO_CHAR(txn_date,'YYYY-MM') AS months,
	SUM(CASE WHEN txn_type LIKE 'dep%' THEN txn_amount ELSE -txn_amount END) AS clo_bal
FROM customer_transactions
GROUP BY customer_id,months
)
SELECT
	customer_id,
	months,
	SUM(clo_bal) OVER(PARTITION BY customer_id ORDER BY months) AS clo_bal
FROM tt
GROUP BY customer_id,months,clo_bal;

OUTPUT
"customer_id"	"months"	"clo_bal"
1	"2020-01"	312
1	"2020-03"	-640
2	"2020-01"	549
2	"2020-03"	610
3	"2020-01"	144
3	"2020-02"	-821
3	"2020-03"	-1222

--What is the percentage of customers who increase their closing balance by more than 5%?
WITH tt1 AS (
	SELECT
		customer_id,
		TO_CHAR(txn_date,'YYYY-MM') AS months,
		SUM(CASE WHEN txn_type LIKE 'dep%' THEN txn_amount ELSE -txn_amount END) AS clo_bal
	FROM customer_transactions
	GROUP BY customer_id, months
),
tt2 AS (
	SELECT
		customer_id,
		months,
		SUM(clo_bal) OVER(PARTITION BY customer_id ORDER BY months) AS clo_bal
	FROM tt1),
tt3 AS (
	SELECT
		customer_id,
		months,
		clo_bal,
		LAG(clo_bal) OVER(PARTITION BY customer_id ORDER BY months) AS prev_bal
	FROM tt2),
tt4 AS (
	SELECT
		customer_id,
		months,
		clo_bal,
		100*(clo_bal-prev_bal)/NULLIF(CASE WHEN prev_bal>0 THEN prev_bal ELSE -prev_bal END,0) AS percentage_change
	FROM tt3)
SELECT
	100*COUNT(DISTINCT customer_id)/(SELECT COUNT(DISTINCT customer_id) FROM customer_transactions)::FLOAT AS perc_cust
FROM tt4
WHERE percentage_change>5;

OUTPUT
"perc_cust"
67

--C. Data Allocation Challenge

--running customer balance column that includes the impact each transaction
WITH tt1 AS (
SELECT 
	customer_id,
	txn_date,
	SUM(CASE WHEN txn_type LIKE 'dep%' THEN txn_amount ELSE -txn_amount END) OVER(PARTITION BY customer_id ORDER BY txn_date) AS clo_bal
FROM customer_transactions
)
SELECT * FROM tt1;

OUTPUT
"customer_id"	"txn_date"	"clo_bal"
1	"2020-01-02"	312
1	"2020-03-05"	-300
1	"2020-03-17"	24
1	"2020-03-19"	-640
2	"2020-01-03"	549
2	"2020-03-24"	610
3	"2020-01-27"	144
3	"2020-02-22"	-821
3	"2020-03-05"	-1034
3	"2020-03-19"	-1222
3	"2020-04-12"	-729

--customer balance at the end of each month
WITH tt1 AS (
SELECT
	customer_id,
	TO_CHAR(txn_date,'YYYY-MM') AS months,
	SUM(CASE WHEN txn_type LIKE 'dep%' THEN txn_amount
		 ELSE -txn_amount 
	END) AS txn_amount
FROM customer_transactions
GROUP BY customer_id, months
),
tt2 AS (
SELECT
	customer_id,
	months,
	txn_amount,
	LAG(txn_amount,1) OVER(PARTITION BY customer_id ORDER BY months) AS pre_amount
FROM tt1)
SELECT
	customer_id,
	months,
	SUM(txn_amount+COALESCE(pre_amount,0)) AS col_bal
FROM tt2
GROUP BY customer_id,months;

OUTPUT
"customer_id"	"months"	"col_bal"
1	"2020-01"	312
1	"2020-03"	-640
2	"2020-01"	549
2	"2020-03"	610
3	"2020-01"	144
3	"2020-02"	-821
3	"2020-03"	-1366
3	"2020-04"	92
4	"2020-01"	848
4	"2020-03"	655

--minimum, average and maximum values of the running balance for each customer
WITH tt1 AS (
SELECT
	customer_id,
	TO_CHAR(txn_date,'yyyy-mm') AS txn_date,
	SUM(CASE WHEN txn_type LIKE 'dep%' THEN txn_amount
	   		 ELSE -txn_amount
	    END) OVER(PARTITION BY customer_id ORDER BY txn_date) AS running_tot
FROM customer_transactions
)
SELECT
	customer_id,
	MIN(running_tot) AS minium_bal,
	ROUND(AVG(running_tot),2) AS avg_bal,
	MAX(running_tot) AS max_bal
FROM tt1
GROUP BY customer_id;

OUTPUT
"customer_id"	"minium_bal"	"avg_bal"	"max_bal"
1	-640	-151.00	312
2	549	579.50	610
3	-1222	-732.40	144
4	458	653.67	848
5	-2413	-135.45	1780
6	-552	624.00	2197
7	887	2268.69	3539
8	-1029	173.70	1363
9	-91	1021.70	2030
10	-5090	-2229.83	556





