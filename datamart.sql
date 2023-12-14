--Data cleaning
CREATE TABLE clean_weekly_sales AS
SELECT
	TO_DATE(week_date,'DD/MM/YY') AS week_date,
	FLOOR(EXTRACT(DAY FROM TO_DATE(week_date,'DD/MM/YY')-DATE_TRUNC('Year',TO_DATE(week_date,'DD/MM/YY')))/7+1) AS week_number,
	EXTRACT(Month FROM TO_DATE(week_date,'DD/MM/YY')) AS month_number,
	EXTRACT(Year From TO_DATE(week_date,'DD/MM/YY')) AS calendar_year,
	region,
	platform,
	CASE WHEN segment IN ('C1','F1','C2','F2','C3','C4','F3','F4') THEN segment
		 ELSE 'Unknown'
	END AS segment,
	CASE WHEN segment IN ('C1','F1') THEN 'Young Adults'
		 WHEN segment IN ('C2','F2') THEN 'Familes'
		 WHEN segment IN ('C3','C4','F3','F4') THEN 'Retires'
		 ELSE 'Unknown'
	END AS age_band,
	CASE WHEN segment LIKE 'C%' THEN 'Couples'
		 WHEN segment LIKE 'F%' THEN 'Familes'
		 ELSE 'Unknown'
	END AS demographic,
	sales,
	transactions,
	ROUND(sales/transactions::DECIMAL,2) AS avg_transaction
FROM weekly_sales;

--Data exploration
--What day of the week is used for each week_date value?
SELECT
	DISTINCT TO_CHAR(week_date,'Day') AS day_of_the_week
FROM clean_weekly_sales;

OUTPUT
"day_of_the_week"
"Monday   "

--What range of week numbers are missing from the dataset?
SELECT GENERATE_SERIES(1,53) AS missing_weeks
EXCEPT
SELECT DISTINCT week_number FROM clean_weekly_sales
ORDER BY missing_weeks;

OUTPUT
"missing_weeks"
1
2
3
4
5
6
7
8
9
10
11
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53

--How many total transactions were there for each year in the dataset?
SELECT 
	calendar_year,
	SUM(transactions) AS sum_of_transactions
FROM clean_weekly_sales
GROUP BY calendar_year;

OUTPUT
"calendar_year"	"sum_of_transactions"
2019	365639285
2018	346406460
2020	375813651

--What is the total sales for each region for each month?
SELECT
	region,
	TO_CHAR(TO_DATE(month_number::TEXT,'MM'),'Month') AS months,
	SUM(sales)
FROM clean_weekly_sales
GROUP BY region,months,month_number
ORDER BY region,month_number;

OUTPUT:
"region"	"months"	"sum"
"AFRICA"	"March    "	567767480
"AFRICA"	"April    "	1911783504
"AFRICA"	"May      "	1647244738
"AFRICA"	"June     "	1767559760
"AFRICA"	"July     "	1960219710
"AFRICA"	"August   "	1809596890
"AFRICA"	"September"	276320987
"ASIA"	"March    "	529770793
"ASIA"	"April    "	1804628707
"ASIA"	"May      "	1526285399

--What is the total count of transactions for each platform
SELECT
	platform,
	SUM(transactions)
FROM clean_weekly_sales
GROUP BY platform;

OUTPUT
"platform"	"sum"
"Shopify"	5925169
"Retail"	1081934227

----What is the percentage of sales for Retail vs Shopify for each month?
WITH tt1 AS (
SELECT
	calendar_year,
	month_number,
	platform,
	SUM(sales) AS monthly_sales
FROM clean_weekly_sales
GROUP BY calendar_year,month_number,platform
ORDER BY calendar_year,month_number,platform
)
SELECT
	calendar_year,
	month_number,
	ROUND(100*MAX(CASE WHEN platform LIKE 'Ret%' THEN monthly_sales END)/SUM(monthly_sales),2) AS retail,
	ROUND(100*MAX(CASE WHEN platform LIKE 'Sho%' THEN monthly_sales END)/SUM(monthly_sales),2) AS shopify
FROM tt1
GROUP BY calendar_year,month_number;

OUTPUT
"calendar_year"	"month_number"	"retail"	"shopify"
2018	3	97.92	2.08
2018	4	97.93	2.07
2018	5	97.73	2.27
2018	6	97.76	2.24
2018	7	97.75	2.25
2018	8	97.71	2.29
2018	9	97.68	2.32
2019	3	97.71	2.29
2019	4	97.80	2.20
2019	5	97.52	2.48

--What is the percentage of sales by demographic for each year in the dataset?
WITH tt1 AS (
SELECT
	demographic,
	calendar_year,
	SUM(sales) AS yearly_sales
FROM clean_weekly_sales
GROUP BY demographic,calendar_year)
SELECT
	calendar_year,
	ROUND(100*MAX(CASE WHEN demographic LIKE 'Familes' THEN yearly_sales END)/SUM(yearly_sales),2) AS families,
	ROUND(100*MAX(CASE WHEN demographic LIKE 'Couples' THEN yearly_sales END)/SUM(yearly_sales),2) AS Couples,
	ROUND(100*MAX(CASE WHEN demographic LIKE 'Unknown' THEN yearly_sales END)/SUM(yearly_sales),2) AS Unknown
FROM tt1
GROUP BY calendar_year;	

OUTPUT
"calendar_year"	"families"	"couples"	"unknown"
2018	31.99	26.38	41.63
2019	32.47	27.28	40.25
2020	32.73	28.72	38.55

--Which age_band and demographic values contribute the most to Retail sales?
SELECT
	age_band,
	demographic,
	SUM(sales) AS tot_sales,
	ROUND(100*SUM(sales)/(SELECT SUM(sales) FROM clean_weekly_sales WHERE platform='Retail')::DECIMAL,2) AS contribution
FROM clean_weekly_sales
WHERE platform='Retail'
GROUP BY age_band,demographic
ORDER BY contribution DESC;

OUTPUT
"age_band"	"demographic"	"tot_sales"	"contribution"
"Unknown"	"Unknown"	16067285533	40.52
"Retires"	"Familes"	6634686916	16.73
"Retires"	"Couples"	6370580014	16.07
"Familes"	"Familes"	4354091554	10.98
"Young Adults"	"Couples"	2602922797	6.56
"Familes"	"Couples"	1854160330	4.68
"Young Adults"	"Familes"	1770889293	4.47

--Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT
	platform,
	calendar_year,
	ROUND(AVG(avg_transaction),0) as avg_transaction,
	SUM(sales)/SUM(transactions) as avg_grp
FROM clean_weekly_sales
GROUP BY platform,calendar_year
ORDER BY calendar_year;

OUTPUT
"platform"	"calendar_year"	"avg_transaction"	"avg_grp"
"Shopify"	2018	188	192
"Retail"	2018	43	36
"Shopify"	2019	178	183
"Retail"	2019	42	36
"Retail"	2020	41	36
"Shopify"	2020	175	179

--What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
WITH tt1 AS (
SELECT
	DISTINCT(week_number) AS week_num
FROM data_mart.clean_weekly_sales
WHERE week_date='2020-06-15'),
tt2 AS (
SELECT
	SUM(CASE WHEN week_number BETWEEN week_num-4 AND week_num-1 THEN sales END) AS before_sales,
	SUM(CASE WHEN week_number BETWEEN week_num AND week_num+3 THEN sales END) AS after_sales
FROM tt1,data_mart.clean_weekly_sales
WHERE calendar_year=2020
)
SELECT
	before_sales,
	after_sales,
	ROUND(100*(after_sales-before_sales)/before_sales::DECIMAL,2) AS perc
FROM tt2;

OUTPUT
"before_sales"	"after_sales"	"perc"
2345878357	2318994169	-1.15

--What about the entire 12 weeks before and after?
WITH tt1 AS (
SELECT
	DISTINCT(week_number) AS week_num
FROM data_mart.clean_weekly_sales
WHERE week_date='2020-06-15'),
tt2 AS (
SELECT
	SUM(CASE WHEN week_number BETWEEN week_num-12 AND week_num-1 THEN sales END) AS before_sales,
	SUM(CASE WHEN week_number BETWEEN week_num AND week_num+11 THEN sales END) AS after_sales
FROM tt1,data_mart.clean_weekly_sales
WHERE calendar_year=2020
)
SELECT
	before_sales,
	after_sales,
	ROUND(100*(after_sales-before_sales)/before_sales::DECIMAL,2) AS perc
FROM tt2;

OUTPUT
"before_sales"	"after_sales"	"perc"
7126273147	6973947753	-2.14

--How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH tt1 AS (
SELECT
	DISTINCT(week_number) AS week_num
FROM data_mart.clean_weekly_sales
WHERE week_date='2020-06-15'),
tt2 AS (
SELECT
	calendar_year,
	SUM(CASE WHEN week_number BETWEEN week_num-3 AND week_num-1 THEN sales END) AS before_sales,
	SUM(CASE WHEN week_number BETWEEN week_num AND week_num+3 THEN sales END) AS after_sales
FROM tt1,data_mart.clean_weekly_sales
GROUP BY calendar_year
)
SELECT
	calendar_year,
	before_sales,
	after_sales,
	ROUND(100*(after_sales-before_sales)/before_sales::DECIMAL,2) AS perc
FROM tt2
GROUP BY calendar_year,before_sales,after_sales;

OUTPUT
"calendar_year"	"before_sales"	"after_sales"	"perc"
2018	1602763447	2129242914	32.85
2019	1688891616	2252326390	33.36
2020	1760870267	2318994169	31.70

WITH tt1 AS (
SELECT
	DISTINCT(week_number) AS week_num
FROM data_mart.clean_weekly_sales
WHERE week_date='2020-06-15'),
tt2 AS (
SELECT
	calendar_year,
	SUM(CASE WHEN week_number BETWEEN week_num-12 AND week_num-1 THEN sales END) AS before_sales,
	SUM(CASE WHEN week_number BETWEEN week_num AND week_num+11 THEN sales END) AS after_sales
FROM tt1,data_mart.clean_weekly_sales
GROUP BY calendar_year
)
SELECT
	calendar_year,
	before_sales,
	after_sales,
	ROUND(100*(after_sales-before_sales)/before_sales::DECIMAL,2) AS perc
FROM tt2
GROUP BY calendar_year,before_sales,after_sales;

OUTPUT
"calendar_year"	"before_sales"	"after_sales"	"perc"
2018	6396562317	6500818510	1.63
2019	6883386397	6862646103	-0.30
2020	7126273147	6973947753	-2.14



