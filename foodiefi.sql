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
	EXTRACT(MONTH FROM start_date) AS month_number,
	INITCAP(TO_CHAR(start_date,'month')) AS month_name,
	COUNT(customer_id) as customer_count
FROM foodie_fi.subscriptions
WHERE plan_id= (SELECT plan_id FROM foodie_fi.plans WHERE plan_name='trial')
GROUP BY month_name,month_number
ORDER BY month_number;

OUTPUT
"month_number"	"month_name"	"customer_count"
1	"January  "	88
2	"February "	68
3	"March    "	94
4	"April    "	81
5	"May      "	88
6	"June     "	79
7	"July     "	89
8	"August   "	88
9	"September"	87
10	"October  "	79
11	"November "	75
12	"December "	84

--What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT 
	p.plan_id,
	p.plan_name,
	COUNT(s.start_date)
FROM foodie_fi.plans p INNER JOIN foodie_fi.subscriptions s
ON p.plan_id=s.plan_id
WHERE EXTRACT(YEAR FROM start_date)>'2020'
GROUP BY p.plan_id,p.plan_name
ORDER BY p.plan_id;

OUTPUT
"plan_id"	"plan_name"	"count"
1	"basic monthly"	8
2	"pro monthly"	60
3	"pro annual"	63
4	"churn"	71

--What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
select
	round((sum(case when p.plan_name='churn' then 1 else 0 end)*100)::numeric/(count(distinct(s.customer_id)))::numeric,1) as percentage_of_churn
from foodie_fi.subscriptions s inner join foodie_fi.plans p
on s.plan_id=p.plan_id;

OUTPUT
"percentage_of_churn"
30.7

