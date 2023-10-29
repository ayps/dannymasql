--naming conventions
--customer orders temporary table - cot
DROP TABLE IF EXISTS cot;
CREATE TABLE cot AS
	SELECT 
		order_id,
		customer_id,
		pizza_id,
		CASE WHEN exclusions = 'null' or exclusions = '' THEN NULL
			 ELSE exclusions
		END AS exclusions,
		CASE WHEN extras ='null' or extras='' THEN NULL
			 ELSE extras
		END AS extras,
		order_time
FROM pizza_runner.customer_orders;
--runner orders temporary table - rot
DROP TABLE IF EXISTS rot;
CREATE TABLE rot as
	SELECT 
		order_id,
		runner_id,
		CASE 
			WHEN pickup_time='null' OR pickup_time='' THEN NULL
			ELSE CAST (pickup_time AS TIMESTAMP) 
			END AS pickup_time,
		CASE
			WHEN distance='null' or distance='' THEN NULL
			ELSE REGEXP_REPLACE(distance, '[A-Za-z]', '', 'g')::FLOAT
			END AS distance,
		CASE
			WHEN duration='null' or duration='' THEN NULL
			ELSE REGEXP_REPLACE(duration, '[^0-9]', '','g')::INT
			END AS duration,
		CASE WHEN cancellation='null' or cancellation='' THEN NULL
			 ELSE cancellation
		END AS cancellation
FROM pizza_runner.runner_orders;

--A. Pizza Metrics
--How many pizzas were ordered?
SELECT COUNT(pizza_id) AS total_pizzas_ordered
FROM cot;

OUTPUT
"total_pizzas_ordered"
14

--How many unique customer orders were made?
SELECT COUNT(DISTINCT(order_id)) AS unique_customer_orders
FROM cot;

OUTPUT
"unique_customer_orders"
10

--How many successful orders were delivered by each runner?
SELECT 
	runner_id AS runners,
	COUNT(distance) as orders_delivered
FROM rot
WHERE distance IS NOT NULL
GROUP BY runners
ORDER BY runners;

OUTPUT
"runners"	"orders_delivered"
1	4
2	3
3	1

--How many of each type of pizza was delivered?
SELECT pizza_name, COUNT(cot.pizza_id) AS pizzas_delivered
FROM cot INNER JOIN pizza_names
ON cot.pizza_id=pizza_names.pizza_id
INNER JOIN rot ON
cot.order_id=rot.order_id
WHERE distance IS NOT NULL
GROUP BY pizza_name;

OUTPUT
"pizza_name"	"pizzas_delivered"
"Meatlovers"	9
"Vegetarian"	3

--How many Vegetarian and Meatlovers were ordered by each customer?
SELECT 
	cot.customer_id AS customers,
	pizza_name, 
	COUNT(cot.pizza_id) AS pizzas_delivered
FROM cot INNER JOIN pizza_names
ON cot.pizza_id=pizza_names.pizza_id
GROUP BY pizza_name, customers
ORDER BY customers;

OUTPUT
"customers"	"pizza_name"	"pizzas_delivered"
101	"Meatlovers"	2
101	"Vegetarian"	1
102	"Meatlovers"	2
102	"Vegetarian"	1
103	"Meatlovers"	3
103	"Vegetarian"	1
104	"Meatlovers"	3
105	"Vegetarian"	1

--What was the maximum number of pizzas delivered in a single order?
SELECT cot.order_id, COUNT(pizza_id) AS most_pizzas_delivered_in_a_single_order
FROM cot INNER JOIN rot
ON cot.order_id=rot.order_id
WHERE distance IS NOT NULL
GROUP BY cot.order_id 
ORDER BY most_pizzas_delivered_in_a_single_order DESC
LIMIT 1;

OUTPUT
"order_id"	"most_pizzas_delivered_in_a_single_order"
4	3

--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT 
	customer_id AS customers,
	SUM (CASE 
		 	WHEN exclusions IS NULL AND extras IS NULL THEN 1
		 	ELSE 0
		 END) AS pizza_with_no_changes,
	SUM (CASE
			WHEN exclusions IS NOT NULL OR extras IS NOT NULL THEN 1
			ELSE 0
		END) AS pizza_with_atlease_one_change
FROM cot INNER JOIN rot
ON cot.order_id=rot.order_id
WHERE distance IS NOT NULL
GROUP BY customers
ORDER BY customers;

OUTPUT
"customers"	"pizza_with_no_changes"	"pizza_with_atlease_one_change"
101	2	0
102	3	0
103	0	3
104	1	2
105	0	1

--How many pizzas were delivered that had both exclusions and extras?
SELECT 
	SUM (CASE
			WHEN exclusions IS NOT NULL AND extras IS NOT NULL THEN 1
			ELSE 0
		END) AS pizzas_with_exclusions_and_extras
FROM cot INNER JOIN rot
ON cot.order_id=rot.order_id
WHERE distance IS NOT NULL;

OUTPUT
"pizzas_with_exclusions_and_extras"
1

--What was the total volume of pizzas ordered for each hour of the day?
WITH hr_vol AS (
	SELECT pizza_id,DATE_PART('hour',order_time) AS hours
	from cot
)
SELECT hours, COUNT(pizza_id)
FROM hr_vol
GROUP BY hours
ORDER BY hours;

OUTPUT
"hours"	"count"
11	1
13	3
18	3
19	1
21	3
23	3

--What was the volume of orders for each day of the week?
WITH days AS (
	SELECT 
		order_id,
		TO_CHAR(order_time,'Day') AS day_of_the_week,
		pizza_id
	FROM cot
),
formatting AS (
	SELECT
		order_id,
		day_of_the_week,
		CASE
			WHEN day_of_the_week LIKE 'Sun%' THEN 1
			WHEN day_of_the_week LIKE 'Mon%' THEN 2
			WHEN day_of_the_week LIKE 'Tue%' THEN 3
			WHEN day_of_the_week LIKE 'Wed%' THEN 4
			WHEN day_of_the_week LIKE 'Thu%' THEN 5
			WHEN day_of_the_week LIKE 'Fri%' THEN 6
			ELSE 7
		END AS ranks,
		pizza_id
	FROM days
)
SELECT day_of_the_week, count(pizza_id)
FROM formatting
GROUP BY day_of_the_week,ranks
ORDER BY ranks;

OUTPUT
"day_of_the_week"	"count"
"Wednesday"	5
"Thursday "	3
"Friday   "	1
"Saturday "	5

--B. Runner and Customer Experience

--How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT 
	EXTRACT(WEEK FROM registration_date+3) AS week_of_the_year,
	COUNT(runner_id) AS number_of_runners_signed
FROM pizza_runner.runners
GROUP BY week_of_the_year
ORDER BY week_of_the_year;

OUTPUT
"week_of_the_year"	"number_of_runners_signed"
1	2
2	1
3	1

--What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
WITH minutes AS (
	SELECT
		DISTINCT (rot.order_id),
		rot.runner_id,
		(rot.pickup_time - cot.order_time) AS time_taken,
		rot.cancellation
	FROM rot RIGHT JOIN cot
	ON rot.order_id=cot.order_id
	ORDER BY rot.order_id
)
SELECT 
	runner_id,
	DATE_TRUNC('minute', AVG(time_taken)+ INTERVAL '30 seconds') AS rounded_time
FROM minutes
GROUP BY runner_id
ORDER BY runner_id;

OUTPUT
"runner_id"	"rounded_time"
1	"00:14:00"
2	"00:20:00"
3	"00:10:00"

--Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH rls AS (
	SELECT
		DISTINCT (rot.order_id),
		rot.runner_id,
		(rot.pickup_time - cot.order_time) AS time_taken,
		rot.cancellation,
		count(pizza_id) AS number_of_pizzas_ordered
	FROM rot RIGHT JOIN cot
	ON rot.order_id=cot.order_id
	WHERE rot.cancellation IS NULL
	GROUP BY rot.order_id,rot.runner_id,rot.pickup_time,cot.order_time,rot.cancellation
)
SELECT number_of_pizzas_ordered, AVG(time_taken)
FROM rls
GROUP BY number_of_pizzas_ordered
ORDER BY number_of_pizzas_ordered DESC;

OUTPUT
"number_of_pizzas_ordered"	"avg"
3	"00:29:17"
2	"00:18:22.5"
1	"00:12:21.4"

--delivered orders temporary tables - dot
DROP TABLE IF EXISTS dot;
CREATE TABLE dot AS
SELECT
	DISTINCT rot.order_id,
	cot.customer_id,
	rot.runner_id,
	rot.pickup_time,
	cot.order_time,
	rot.distance,
	rot.duration,
	rot.cancellation
FROM rot INNER JOIN cot
ON rot.order_id=cot.order_id
WHERE rot.cancellation IS NULL

"customer_id"	"avg_distance_travelled"
101	20
102	18.4
103	23.4
104	10
105	25

"order_id"	"customer_id"	"runner_id"	"pickup_time"	"order_time"	"distance"	"duration"	"cancellation"
1	101	1	"2020-01-01 18:15:34"	"2020-01-01 18:05:02"	20	32	
2	101	1	"2020-01-01 19:10:54"	"2020-01-01 19:00:52"	20	27	
3	102	1	"2020-01-03 00:12:37"	"2020-01-02 23:51:23"	13.4	20	
4	103	2	"2020-01-04 13:53:03"	"2020-01-04 13:23:46"	23.4	40	
5	104	3	"2020-01-08 21:10:57"	"2020-01-08 21:00:29"	10	15	
7	105	2	"2020-01-08 21:30:45"	"2020-01-08 21:20:29"	25	25	
8	102	2	"2020-01-10 00:15:02"	"2020-01-09 23:54:33"	23.4	15	
10	104	1	"2020-01-11 18:50:20"	"2020-01-11 18:34:49"	10	10	

--What was the average distance travelled for each customer?
SELECT 
	customer_id,
	AVG(distance) AS avg_distance_travelled
FROM dot
GROUP BY customer_id
ORDER BY customer_id;

OUTPUT
"customer_id"	"avg_distance_travelled"
101	20
102	18.4
103	23.4
104	10
105	25

--What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration)-MIN(duration) AS time_diff
FROM dot;

OUTPUT
"time_diff"
30

--What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT runner_id, order_id,distance,
  ROUND((distance::numeric / (duration::numeric / 60))::numeric, 2) AS average_speed
FROM dot
ORDER BY runner_id, average_speed;

OUTPUT
"runner_id"	"order_id"	"distance"	"average_speed"
1	1	20	37.50
1	3	13.4	40.20
1	2	20	44.44
1	10	10	60.00
2	4	23.4	35.10
2	7	25	60.00
2	8	23.4	93.60
3	5	10	40.00

--C. Ingredient Optimisation
--pizza order reciepe temporary table por
DROP TABLE IF EXISTS por;
CREATE TABLE por AS
WITH por AS (
	SELECT
		pizza_id,
		UNNEST(STRING_TO_ARRAY(toppings,','))::INT as topping_id
	FROM pizza_runner.pizza_recipes
)
SELECT 
	por.pizza_id,
	por.topping_id,
	pizza_toppings.topping_name
FROM por INNER JOIN pizza_runner.pizza_toppings
ON por.topping_id=pizza_toppings.topping_id

--What are the standard ingredients for each pizza?
SELECT 
	pizza_id,
	STRING_AGG(topping_name,',') AS standard_ingredients
FROM por
GROUP BY pizza_id
ORDER BY pizza_id;

OUTPUT
"pizza_id"	"standard_ingredients"
1	"Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
2	"Cheese,Mushrooms,Onions,Peppers,Tomatoes,Tomato Sauce"

--What was the most commonly added extra?
WITH cte AS (
	
	SELECT 
		UNNEST(STRING_TO_ARRAY(extras,','))::INT AS extras
	FROM cot
),
cte1 AS (
	SELECT
		extras,
		COUNT(*) AS occurence_time
	FROM cte
		GROUP BY extras
	)
SELECT 
	DISTINCT extras,
	topping_name,
	occurence_time
FROM cte1 INNER JOIN por
ON cte1.extras=por.topping_id;

OUTPUT
"extras"	"topping_name"	"occurence_time"
1	"Bacon"	4
4	"Cheese"	1
5	"Chicken"	1

--What was the most common exclusion?
WITH cte AS (
	SELECT 
		UNNEST(STRING_TO_ARRAY(exclusions,','))::INT AS exclusion
	FROM cot
),
cte1 AS (
	SELECT
		exclusion,
		COUNT(*) AS occurence_time
	FROM cte
		GROUP BY exclusion
	)
SELECT 
	DISTINCT exclusion,
	topping_name,
	occurence_time
FROM cte1 INNER JOIN por
ON cte1.exclusion=por.topping_id
ORDER BY occurence_time DESC;

OUTPUT
"exclusion"	"topping_name"	"occurence_time"
4	"Cheese"	4
2	"BBQ Sauce"	1
6	"Mushrooms"	1

--altering cot table to include a record_id column(primary key) for each pizza ordered
ALTER TABLE cot
ADD COLUMN record_id SERIAL PRIMARY KEY;

--creating table for extras
DROP TABLE IF EXISTS EXTRAS;
CREATE TABLE extras AS
SELECT
	record_id,
	UNNEST(STRING_TO_ARRAY(extras,','))::INT AS extras
FROM cot;

--create table for exclusions
DROP TABLE IF EXISTS EXTRAS;
CREATE TABLE extras AS
SELECT
	record_id,
	UNNEST(STRING_TO_ARRAY(extras,','))::INT AS extras
FROM cot;

--create table for exclusions
DROP TABLE IF EXISTS exclusions;
CREATE TABLE exclusions AS
SELECT
	record_id,
	UNNEST(STRING_TO_ARRAY(exclusions,','))::INT AS exclusions
FROM cot;	

--Generate an order item for each record in the customers_orders table in the format of one of the following:
WITH extras_cte AS (
	SELECT 
		record_id,
		'Extra ' || STRING_AGG(topping_name,', ') AS choice
	FROM extras INNER JOIN pizza_runner.pizza_toppings
	ON extras.extras=pizza_toppings.topping_id
	GROUP BY record_id
),
exclusions_cte AS (
	SELECT
		record_id,
		'Exclude ' || STRING_AGG(topping_name,', ') AS choice
	FROM exclusions INNER JOIN pizza_runner.pizza_toppings
	ON exclusions.exclusions=pizza_toppings.topping_id
	GROUP BY record_id
),
union_cte AS (
	SELECT * FROM extras_cte
	UNION
	SELECT * FROM exclusions_cte
)
SELECT
	cot.order_id,
	CONCAT_WS('-',pizza_names.pizza_name,STRING_AGG(union_cte.choice,'-')) AS pizza_topping
FROM cot LEFT JOIN union_cte
ON cot.record_id=union_cte.record_id
JOIN pizza_runner.pizza_names ON
cot.pizza_id=pizza_names.pizza_id
GROUP BY cot.record_id,cot.order_id,pizza_names.pizza_name;

"order_id"	"pizza_topping"
1	"Meatlovers"
2	"Meatlovers"
3	"Meatlovers"
3	"Vegetarian"
4	"Meatlovers-Exclude Cheese"
4	"Meatlovers-Exclude Cheese"
4	"Vegetarian-Exclude Cheese"
5	"Meatlovers-Extra Bacon"
6	"Vegetarian"
7	"Vegetarian-Extra Bacon"
8	"Meatlovers"
9	"Meatlovers-Extra Bacon, Chicken-Exclude Cheese"
10	"Meatlovers"
10	"Meatlovers-Extra Bacon, Cheese-Exclude BBQ Sauce, Mushrooms"

--Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
WITH cte AS (
	SELECT
		cot.record_id,
		pizza_name,
		CASE WHEN por.topping_id IN (
							SELECT extras
							FROM extras WHERE cot.record_id=extras.record_id)
			THEN '2X'|| por.topping_name
			ELSE por.topping_name
		END AS toppings
	FROM cot LEFT JOIN pizza_runner.pizza_names
	ON cot.pizza_id=pizza_names.pizza_id
	JOIN por
	ON cot.pizza_id=por.pizza_id
	WHERE por.topping_id NOT IN (SELECT exclusions FROM exclusions
								WHERE cot.record_id=exclusions.record_id)
)
SELECT 
	record_id,
	CONCAT(pizza_name||':'||STRING_AGG(toppings,',' ORDER BY toppings)) AS ing_lists
FROM cte
GROUP BY record_id, pizza_name;

OUTPUT
"record_id"	"ing_lists"
1	"Meatlovers:Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
2	"Meatlovers:Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
3	"Meatlovers:Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
4	"Vegetarian:Cheese,Mushrooms,Onions,Peppers,Tomatoes,Tomato Sauce"
5	"Meatlovers:Bacon,BBQ Sauce,Beef,Chicken,Mushrooms,Pepperoni,Salami"
6	"Meatlovers:Bacon,BBQ Sauce,Beef,Chicken,Mushrooms,Pepperoni,Salami"
7	"Vegetarian:Mushrooms,Onions,Peppers,Tomatoes,Tomato Sauce"
8	"Meatlovers:2XBacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
9	"Vegetarian:Cheese,Mushrooms,Onions,Peppers,Tomatoes,Tomato Sauce"
10	"Vegetarian:Cheese,Mushrooms,Onions,Peppers,Tomatoes,Tomato Sauce"
11	"Meatlovers:Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
12	"Meatlovers:2XBacon,2XChicken,BBQ Sauce,Beef,Mushrooms,Pepperoni,Salami"
13	"Meatlovers:Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
14	"Meatlovers:2XBacon,2XCheese,Beef,Chicken,Pepperoni,Salami"

--What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH cte AS 
(SELECT 
	cot.record_id,
	por.topping_name,
	CASE WHEN por.topping_id IN ( SELECT extras FROM extras
								  	WHERE extras.record_id=cot.record_id)
		 THEN 2
		 ELSE 1
	END AS times_used
 FROM cot
 JOIN por ON
 cot.pizza_id=por.pizza_id
 JOIN pizza_runner.pizza_names
 ON cot.pizza_id=pizza_names.pizza_id
 JOIN rot
 ON cot.order_id=rot.order_id
 WHERE por.topping_id NOT IN (SELECT exclusionS FROM exclusions
							  WHERE exclusions.record_id=cot.record_id)
 AND rot.cancellation IS NULL
)
SELECT
	topping_name,
	SUM(times_used) AS times_used
FROM cte
GROUP BY topping_name
ORDER BY times_used DESC;

OUTPUT
"topping_name"	"times_used"
"Bacon"	11
"Mushrooms"	11
"Cheese"	10
"Pepperoni"	9
"Salami"	9
"Chicken"	9
"Beef"	9
"BBQ Sauce"	8
"Tomato Sauce"	3
"Onions"	3
"Peppers"	3
"Tomatoes"	3

--D. Pricing and Ratings
--If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
WITH cte AS (
	SELECT 
		order_id,
		CASE WHEN pizza_name='Meatlovers' THEN 12
			 ELSE 10
		END AS pricing
	FROM cot INNER JOIN pizza_runner.pizza_names
	ON cot.pizza_id=pizza_names.pizza_id
)
SELECT 
	SUM(pricing) AS total_money
FROM cte INNER JOIN rot
ON cte.order_id=rot.order_id
WHERE rot.cancellation is NULL;

OUTPUT
"total_money"
138

--What if there was an additional $1 charge for any pizza extras?
WITH cte AS (
	SELECT 
		order_id,
		CASE WHEN pizza_name='Meatlovers' THEN 12
			 ELSE 10
		END AS pricing,
		cot.extras,
		cot.exclusions
	FROM cot INNER JOIN pizza_runner.pizza_names
	ON cot.pizza_id=pizza_names.pizza_id
)
SELECT 
	SUM(CASE WHEN extras IS NULL THEN pricing
		 WHEN CHAR_LENGTH(extras)=1 THEN pricing+1
	ELSE pricing+2
	END) AS pricing_with_extras
FROM cte
INNER JOIN rot
ON cte.order_id=rot.order_id
WHERE rot.cancellation IS NULL;

OUTPUT
"pricing_with_extras"
142

--The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings
(order_id INTEGER,
 rating INTEGER);
INSERT INTO ratings
(order_id,rating)
VALUES
(1,2),
(2,3),
(3,4),
(4,5),
(5,1),
(6,NULL),
(7,2),
(8,3),
(9,NULL),
(10,4);

SELECT * FROM ratings;

OUTPUT
"order_id"	"rating"
1	2
2	3
3	4
4	5
5	1
6	
7	2
8	3
9	
10	4

--Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--customer_id--order_id--runner_id--rating--order_time--pickup_time--Time between order and pickup
--Delivery duration--Average speed--Total number of pizzas
SELECT
	cot.customer_id,
	cot.order_id,
	rot.runner_id,
	ratings.rating,
	cot.order_time,
	rot.pickup_time,
	rot.pickup_time-cot.order_time AS time_between,
	duration,
	distance,
	ROUND((distance::numeric / (duration::numeric / 60))::numeric, 2) AS average_speed,
	COUNT(cot.order_id) AS total_number_of_pizzas
FROM cot INNER JOIN rot
ON cot.order_id=rot.order_id
INNER JOIN ratings
ON cot.order_id=ratings.order_id
WHERE rot.cancellation IS NULL
GROUP BY cot.order_id,cot.customer_id,rot.runner_id,ratings.rating,cot.order_time,rot.pickup_time,time_between,rot.duration,rot.distance;

OUTPUT
"customer_id"	"order_id"	"runner_id"	"rating"	"order_time"	"pickup_time"	"time_between"	"duration"	"distance"	"average_speed"	"total_number_of_pizzas"
101	1	1	2	"2020-01-01 18:05:02"	"2020-01-01 18:15:34"	"00:10:32"	32	20	37.50	1
101	2	1	3	"2020-01-01 19:00:52"	"2020-01-01 19:10:54"	"00:10:02"	27	20	44.44	1
102	3	1	4	"2020-01-02 23:51:23"	"2020-01-03 00:12:37"	"00:21:14"	20	13.4	40.20	2
103	4	2	5	"2020-01-04 13:23:46"	"2020-01-04 13:53:03"	"00:29:17"	40	23.4	35.10	3
104	5	3	1	"2020-01-08 21:00:29"	"2020-01-08 21:10:57"	"00:10:28"	15	10	40.00	1
105	7	2	2	"2020-01-08 21:20:29"	"2020-01-08 21:30:45"	"00:10:16"	25	25	60.00	1
102	8	2	3	"2020-01-09 23:54:33"	"2020-01-10 00:15:02"	"00:20:29"	15	23.4	93.60	1
104	10	1	4	"2020-01-11 18:34:49"	"2020-01-11 18:50:20"	"00:15:31"	10	10	60.00	2

--If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
WITH cte AS (
	SELECT 
		
		SUM(CASE WHEN pizza_name='Meatlovers' THEN 12
			 ELSE 10
		END) AS pricing
	FROM cot INNER JOIN pizza_runner.pizza_names
	ON cot.pizza_id=pizza_names.pizza_id
	INNER JOIN rot ON rot.order_id=cot.order_id
	WHERE rot.cancellation IS NULL
),
cte_1 AS (
	SELECT 
		SUM(distance)*0.3 AS delivery_cost
	FROM rot
)

SELECT cte.pricing,ROUND(cte_1.delivery_cost::NUMERIC,2),(SELECT * FROM cte)-(SELECT * from cte_1) AS total_profit
FROM cte,cte_1;

OUTPUT
"pricing"	"round"	"total_profit"
138	43.56	94.44



