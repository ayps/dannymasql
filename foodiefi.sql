--A. Customer Journey
--Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
SELECT 
	s.customer_id,
	s.plan_id,
	p.plan_name,
	s.start_date
FROM foodie_fi.subscriptions s INNER JOIN foodie_fi.plans p
ON s.plan_id=p.plan_id
WHERE s.customer_id IN (1,2,11,13,15,16,18,19);

OUTPUT
1	0	"trial"	"2020-08-01"
1	1	"basic monthly"	"2020-08-08"
2	0	"trial"	"2020-09-20"
2	3	"pro annual"	"2020-09-27"
11	0	"trial"	"2020-11-19"
11	4	"churn"	"2020-11-26"
13	0	"trial"	"2020-12-15"
13	1	"basic monthly"	"2020-12-22"
13	2	"pro monthly"	"2021-03-29"
15	0	"trial"	"2020-03-17"
15	2	"pro monthly"	"2020-03-24"
15	4	"churn"	"2020-04-29"
16	0	"trial"	"2020-05-31"
16	1	"basic monthly"	"2020-06-07"
16	3	"pro annual"	"2020-10-21"
18	0	"trial"	"2020-07-06"
18	2	"pro monthly"	"2020-07-13"
19	0	"trial"	"2020-06-22"
19	2	"pro monthly"	"2020-06-29"
19	3	"pro annual"	"2020-08-29"

--How many customers has Foodie-Fi ever had?
SELECT 
	COUNT(DISTINCT(customer_id)) AS total_customers
FROM foodie_fi.subscriptions;

OUTPUT
"total_customers"
1000

--What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT
	INITCAP(TO_CHAR(start_date,'month')) AS	month,
	COUNT(DISTINCT(customer_id)) AS total_cust
FROM foodie_fi.subscriptions s INNER JOIN foodie_fi.plans p
ON s.plan_id=p.plan_id
WHERE plan_name LIKE 'tri%'
GROUP BY month
ORDER BY total_cust DESC;

OUTPUT
"month"	"total_cust"
"March    "	94
"July     "	89
"August   "	88
"May      "	88
"January  "	88
"September"	87
"December "	84
"April    "	81
"June     "	79
"October  "	79
"November "	75
"February "	68

--What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT
	plan_name,
	COUNT(start_date)
FROM foodie_fi.subscriptions s INNER JOIN foodie_fi.plans p
ON s.plan_id=p.plan_id
WHERE start_date>'2020-12-31'
GROUP BY plan_name;

OUTPUT
"plan_name"	"count"
"pro annual"	63
"churn"	71
"pro monthly"	60
"basic monthly"	8

--What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT
	SUM(CASE WHEN plan_name='churn' THEN 1 ELSE 0 END) AS customer_count,
	ROUND((SUM(CASE WHEN plan_name='churn' THEN 1 ELSE 0 END)*100::NUMERIC/(COUNT(DISTINCT(customer_id))::NUMERIC)),1) AS churn_rate
FROM foodie_fi.subscriptionS s INNER JOIN foodie_fi.plans p
ON s.plan_id=p.plan_id;

"customer_count"	"churn_rate"
307	30.7

--How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH cte_churn AS (
	SELECT
		s.*,
		LAG(plan_id,1) OVER(PARTITION BY customer_id ORDER BY plan_id) AS previous_plan
	FROM foodie_fi.subscriptions s
)
SELECT 
	COUNT(*) AS churn_count,
	ROUND(COUNT(*)*100/(SELECT COUNT(DISTINCT(customer_id)) FROM cte_churn WHERE plan_id IN (0,4)),0) AS churn_rate
FROM cte_churn
WHERE plan_id=4 AND previous_plan=0;

OUTPUT
"churn_count"	"churn_rate"
92	9



