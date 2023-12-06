--A. Customer Journey
--Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.
SELECT
	s.*,
	p.plan_name
FROM subscriptions s INNER JOIN plans p
ON s.plan_id=p.plan_id AND s.customer_id IN (1,2,3,4,5,6,7,8)

OUTPUT
"customer_id"	"plan_id"	"start_date"	"plan_name"
1	0	"2020-08-01"	"trial"
1	1	"2020-08-08"	"basic monthly"
2	0	"2020-09-20"	"trial"
2	3	"2020-09-27"	"pro annual"
3	0	"2020-01-13"	"trial"
3	1	"2020-01-20"	"basic monthly"
4	0	"2020-01-17"	"trial"
4	1	"2020-01-24"	"basic monthly"
4	4	"2020-04-21"	"churn"
5	0	"2020-08-03"	"trial"
5	1	"2020-08-10"	"basic monthly"
6	0	"2020-12-23"	"trial"
6	1	"2020-12-30"	"basic monthly"
6	4	"2021-02-26"	"churn"
7	0	"2020-02-05"	"trial"
7	1	"2020-02-12"	"basic monthly"
7	2	"2020-05-22"	"pro monthly"
8	0	"2020-06-11"	"trial"
8	1	"2020-06-18"	"basic monthly"
8	2	"2020-08-03"	"pro monthly"

--How many customers has Foodie-Fi ever had?
SELECT
	COUNT(DISTINCT customer_id) AS tot_no_cust
FROM subscriptions;

OUTPUT
"tot_no_cust"
1000

--What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT
	INITCAP(TO_CHAR(start_date,'month')) AS mon,
	COUNT(*)
FROM subscriptions s INNER JOIN plans p
ON s.plan_id=p.plan_id
WHERE p.plan_name LIKE 'tri%'
GROUP BY mon
ORDER BY MIN(start_date);

OUTPUT
"mon"	"count"
"January  "	88
"February "	68
"March    "	94
"April    "	81
"May      "	88
"June     "	79
"July     "	89
"August   "	88
"September"	87
"October  "	79
"November "	75
"December "	84

--What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT
	p.plan_name,
	COUNT(s.start_date)
FROM subscriptions s INNER JOIN plans p
ON s.plan_id=p.plan_id AND s.start_date>'2020-12-31'
GROUP BY p.plan_name,p.plan_id
ORDER BY p.plan_id;

OUTPUT
"plan_name"	"count"
"basic monthly"	8
"pro monthly"	60
"pro annual"	63
"churn"	71

--What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT
	SUM(CASE WHEN p.plan_name LIKE 'chu%' THEN 1 ELSE 0 END) AS churn_tot,
	ROUND(SUM(CASE WHEN p.plan_name LIKE 'chu%' THEN 1 ELSE 0 END)*100/COUNT(DISTINCT customer_id)::DECIMAL,1)
FROM subscriptions s INNER JOIN plans p
ON s.plan_id=p.plan_id;

OUTPUT
"churn_tot"	"round"
307	30.7

--How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
SELECT
	COUNT(DISTINCT customer_id) AS chur_aft_tri_cou,
	ROUND(COUNT(DISTINCT customer_id)*100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions WHERE plan_id IN (0,4)),0)
FROM(
SELECT
	*,
	LEAD(plan_id,1) OVER(PARTITION BY customer_id ORDER BY start_date) AS next_pln
FROM subscriptions)
WHERE plan_id=0 AND next_pln=4

OUTPUT
"chur_aft_tri_cou"	"round"
92	9

--What is the number and percentage of customer plans after their initial free trial?
SELECT
	p.plan_name,
	COUNT(pln.customer_id),
	ROUND(COUNT(pln.customer_id)*100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions)::DECIMAL,1)
FROM(SELECT
	s.*,
	LEAD(plan_id,1) OVER(PARTITION BY s.customer_id ORDER BY s.start_date) AS next_plan
FROM subscriptions s) AS pln INNER JOIN plans p
ON pln.next_plan=p.plan_id
WHERE pln.next_plan IS NOT NULL AND pln.plan_id=0
GROUP BY p.plan_name;

OUTPUT
"plan_name"	"count"	"round"
"pro annual"	37	3.7
"churn"	92	9.2
"pro monthly"	325	32.5
"basic monthly"	546	54.6

--What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
SELECT
	p.plan_name,
	COUNT(sub.customer_id),
	ROUND(COUNT(sub.customer_id)*100/(SELECT COUNT(DISTINCT customer_id) FROM subscriptions WHERE start_date<='2020-12-31')::DECIMAL,1)
FROM(
SELECT
	s.*,
	LEAD(s.start_date,1) OVER(PARTITION BY customer_id ORDER BY s.start_date) as next_date
FROM subscriptions s
WHERE start_date<='2020-12-31') AS SUB INNER JOIN plans p
ON sub.plan_id=p.plan_id
WHERE sub.next_date IS NULL
GROUP BY p.plan_name;

OUTPUT
"plan_name"	"count"	"round"
"basic monthly"	224	22.4
"churn"	236	23.6
"pro annual"	195	19.5
"pro monthly"	326	32.6
"trial"	19	1.9

--How many customers have upgraded to an annual plan in 2020?
SELECT
	COUNT(DISTINCT s.customer_id) AS tot_upgrade_to_annual_plan
FROM subscriptions s WHERE start_date BETWEEN '2020-01-01' AND '2020-12-31' AND plan_id=3

OUTPUT
"tot_upgrade_to_annual_plan"
195

--How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
SELECT
	ROUND(AVG(n.start_date-s.start_date),0)
FROM subscriptions n JOIN subscriptions s
ON n.customer_id=s.customer_id
WHERE n.plan_id=3 AND s.plan_id=0;

OUTPUT
"round"
105

--Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH trial_plan AS (
	SELECT
		customer_id,
		start_date AS trial_date
	FROM subscriptions WHERE plan_id=0),
annual_plan AS (
	SELECT
		customer_id,
		start_date AS annual_date
	FROM subscriptions WHERE plan_id=3)
SELECT
	CONCAT(FLOOR((annual_date-trial_date)/30)*30,'-',FLOOR((annual_date-trial_date)/30)*30+30,' days') AS days,
	COUNT(trial_plan.customer_id) AS tot_cust,
	ROUND(AVG(annual_date-trial_date),0) AS avg_days_to_upgrade
FROM trial_plan JOIN annual_plan
ON trial_plan.customer_id=annual_plan.customer_id
GROUP BY (annual_date-trial_date)/30;

OUTPUT
"days"	"tot_cust"	"avg_days_to_upgrade"
"150-180 days"	35	162
"120-150 days"	43	133
"300-330 days"	1	327
"180-210 days"	27	190
"60-90 days"	33	71
"210-240 days"	4	224
"30-60 days"	25	42
"240-270 days"	5	257
"330-360 days"	1	346
"270-300 days"	1	285
"90-120 days"	35	100
"0-30 days"	48	10

--How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
SELECT
	COUNT(n.customer_id) AS num_of_cust
FROM subscriptions s JOIN subscriptions n
ON n.customer_id=s.customer_id
WHERE n.plan_id=1 AND s.plan_id=2 AND n.start_date>s.start_date;

OUTPUT
"num_of_cust"
0

--payment question
with recursive mt as (
select
	s.customer_id,
	s.plan_id,
	p.plan_name,
	p.price,
	s.start_date as payment_date,
	lead(s.start_date,1) over(partition by s.customer_id order by s.start_date) as next_date
from subscriptions s inner join plans p
on s.plan_id=p.plan_id
where s.plan_id not in (0,4) and s.start_date between '2020-01-01' and '2020-12-31'),
tt1 as (
select
	customer_id,
	plan_id,
	plan_name,
	price,
	payment_date,
	coalesce(next_date,'2020-12-31') as next_date
from mt),
tt2 as (
select
	customer_id,
	plan_Id,
	plan_name,
	price,
	payment_date,
	next_date
	 from tt1
union all
select
	customer_id,
	plan_Id,
	plan_name,
	price,
	DATE((payment_date + INTERVAL '1 MONTH')) as payment_date, 
    next_date FROM tt2
  	WHERE next_date > DATE((payment_date + INTERVAL '1 MONTH'))
  	AND plan_name <> 'pro annual'
),
tt3 as (
select
	*,
	lag(plan_id,1)over(partition by customer_id order by payment_date) as last_plan,
	lag(price,1) over (partition by customer_id order by payment_date) as last_price,
	dense_rank() over(partition by customer_id order by payment_date) as payment_order
from tt2
order by customer_id,payment_date)
select
	customer_id,plan_id,plan_name,payment_date,
	case when plan_id =2 and last_plan =1
		 then price-last_price
		 when plan_id=3 and last_plan in (1,2)
		 then price-last_price
		 else price
	end as amount,payment_order
from tt3;

OUTPUT
"customer_id"	"plan_id"	"plan_name"	"payment_date"	"amount"	"payment_order"
1	1	"basic monthly"	"2020-08-08"	9.90	1
1	1	"basic monthly"	"2020-09-08"	9.90	2
1	1	"basic monthly"	"2020-10-08"	9.90	3
1	1	"basic monthly"	"2020-11-08"	9.90	4
1	1	"basic monthly"	"2020-12-08"	9.90	5
2	3	"pro annual"	"2020-09-27"	199.00	1
3	1	"basic monthly"	"2020-01-20"	9.90	1
3	1	"basic monthly"	"2020-02-20"	9.90	2
3	1	"basic monthly"	"2020-03-20"	9.90	3
3	1	"basic monthly"	"2020-04-20"	9.90	4
3	1	"basic monthly"	"2020-05-20"	9.90	5
3	1	"basic monthly"	"2020-06-20"	9.90	6
3	1	"basic monthly"	"2020-07-20"	9.90	7
3	1	"basic monthly"	"2020-08-20"	9.90	8
3	1	"basic monthly"	"2020-09-20"	9.90	9
3	1	"basic monthly"	"2020-10-20"	9.90	10
3	1	"basic monthly"	"2020-11-20"	9.90	11
3	1	"basic monthly"	"2020-12-20"	9.90	12
4	1	"basic monthly"	"2020-01-24"	9.90	1
4	1	"basic monthly"	"2020-02-24"	9.90	2
