--naming conventions
--customer orders temporary table - cot
CREATE TEMPORARY TABLE cot AS
SELECT
		ROW_NUMBER() OVER() AS record_id,
		order_id,
		customer_id,
		pizza_id,
		CASE WHEN exclusions='' OR exclusions='null'
			 THEN NULL
			 ELSE exclusions
		END AS exclusions,
		CASE WHEN extras='' OR extras='null'
			 THEN NULL
			 ELSE extras
		END AS extras,
		order_time::TIMESTAMP
FROM customer_orders	

--table for extras
CREATE TEMPORARY TABLE extras AS
SELECT
	record_id,
	UNNEST(STRING_TO_ARRAY(extras,','))::INT AS extra
FROM cot;

--table for exclusions
CREATE TEMPORARY TABLE exclusions AS
SELECT
	record_id,
	UNNEST(STRING_TO_ARRAY(exclusions,','))::INT AS exclusion
FROM cot;

--table for pizza recipes - por
DROP TABLE IF EXISTS por;
CREATE TEMPORARY TABLE por AS
WITH por AS (
	SELECT
		pr.pizza_id,
		UNNEST(STRING_TO_ARRAY(pr.toppings,','))::INT AS topping_id
	FROM pizza_recipes pr
)
SELECT
	por.pizza_id,
	por.topping_id,
	pt.topping_name
FROM por INNER JOIN pizza_toppings pt
ON por.topping_id=pt.topping_id;

--runner orders temporary table - rot
CREATE TEMPORARY TABLE rot AS
SELECT
	order_id,
	runner_id,
	(CASE WHEN pickup_time='' OR pickup_time='null'
		 THEN NULL
		 ELSE pickup_time
	END)::TIMESTAMP AS pickup_time,
	CASE WHEN distance='' OR distance='null'
		 THEN NULL
		 ELSE REGEXP_REPLACE(distance,'[A-Za-z]','','g')::FLOAT
	END AS distance_in_km,
	CASE WHEN duration='' OR duration='null'
		 THEN NULL
		 ELSE REGEXP_REPLACE(duration,'[A-Za-z]','','g')::INT
	END AS duration_in_min,
	CASE WHEN cancellation='' OR cancellation='null'
		 THEN NULL
		 ELSE cancellation
	END AS cancellation
FROM runner_orders;

--delivered orders - dot
CREATE TEMPORARY TABLE dot AS
SELECT
	DISTINCT r.order_id,
	r.runner_id,
	c.order_time,
	r.pickup_time::TIMESTAMP,
	r.distance_in_km,
	r.duration_in_min,
	r.cancellation
FROM rot r INNER JOIN cot c
ON r.order_id=c.order_id
WHERE r.cancellation IS NULL;


--A. Pizza Metrics
--How many pizzas were ordered?
SELECT
	COUNT(record_id) AS tot_orders
FROM cot;

OUTPUT
"tot_orders"
14

--How many unique customer orders were made?
SELECT
	COUNT(DISTINCT order_id) AS uni_ord
FROM cot;

OUTPUT
"uni_ord"
10

--How many successful orders were delivered by each runner?
SELECT
	runner_id,
	COUNT(order_id) AS suc_ord
FROM dot
GROUP BY runner_id;

OUTPUT
"runner_id"	"suc_ord"
3	1
2	3
1	4

--How many of each type of pizza was delivered?
SELECT
	p.pizza_name,
	COUNT(c.order_id) AS pizza_del
FROM cot c INNER JOIN pizza_names p
ON c.pizza_id=p.pizza_id
INNER JOIN rot r
ON c.order_id=r.order_id
WHERE r.cancellation IS NULL
GROUP BY p.pizza_name;

OUTPUT
"pizza_name"	"pizza_del"
"Meatlovers"	9
"Vegetarian"	3

--How many Vegetarian and Meatlovers were ordered by each customer?
SELECT
	c.customer_id,
	p.pizza_name,
	COUNT(order_id) AS no_pizza
FROM cot c INNER JOIN pizza_names p
ON c.pizza_id=p.pizza_id
GROUP BY c.customer_id,p.pizza_name
ORDER BY c.customer_id;

OUTPUT
"customer_id"	"pizza_name"	"no_pizza"
101	"Meatlovers"	2
101	"Vegetarian"	1
102	"Meatlovers"	2
102	"Vegetarian"	1
103	"Meatlovers"	3
103	"Vegetarian"	1
104	"Meatlovers"	3
105	"Vegetarian"	1

--What was the maximum number of pizzas delivered in a single order?
SELECT
	c.customer_id,
	c.order_id,
	COUNT(c.order_id) AS max_ord
FROM cot c INNER JOIN rot r
ON c.order_id=r.order_id
WHERE cancellation IS NULL
GROUP BY c.customer_id,c.order_id
ORDER BY max_ord DESC
LIMIT 1;

OUTPUT
"customer_id"	"order_id"	"max_ord"
103	4	3

--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT
	c.customer_id,
	SUM(CASE WHEN extras IS NULL AND exclusions IS NULL
	   		 THEN 1
	   		 ELSE 0
	   	END)AS no_changes,
	SUM(CASE WHEN extras IS NOT NULL OR exclusions IS NOT NULL
	   		 THEN 1
	   		 ELSE 0
	    END)AS at_one_change
FROM cot c INNER JOIN rot r
ON c.order_id=r.order_id
WHERE r.cancellation IS NULL
GROUP BY customer_id;

OUTPUT
"customer_id"	"no_changes"	"at_one_change"
101	2	0
102	3	0
103	0	3
104	1	2
105	0	1

--How many pizzas were delivered that had both exclusions and extras?
SELECT
	SUM(CASE WHEN extras IS NOT NULL AND exclusions IS NOT NULL
	   		 THEN 1
	   		 ELSE 0
	    END)AS exc_and_ext
FROM cot c INNER JOIN rot r
ON c.order_id=r.order_id
WHERE r.cancellation IS NULL;

OUTPUT
"exc_and_ext"
1

--What was the total volume of pizzas ordered for each hour of the day?
SELECT
	EXTRACT(HOUR FROM order_time) AS hour,
	COUNT(order_id)
FROM cot
GROUP BY hour
ORDER BY hour;

OUTPUT
"hour"	"count"
11	1
13	3
18	3
19	1
21	3
23	3

--What was the volume of orders for each day of the week?
SELECT
	TO_CHAR(order_time,'D') AS day_of_the_week,
	TO_CHAR(order_time,'Day') AS days,
	COUNT(order_id)
FROM cot
GROUP BY day_of_the_week,days
ORDER BY day_of_the_week;

OUTPUT
"day_of_the_week"	"days"	"count"
"4"	"Wednesday"	5
"5"	"Thursday "	3
"6"	"Friday   "	1
"7"	"Saturday "	5

--B. Runner and Customer Experience

--How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT
	EXTRACT(WEEK FROM registration_date+3) AS weeks,
	COUNT(runner_id)
FROM runners
GROUP BY weeks
ORDER BY weeks;

OUTPUT
"weeks"	"count"
1	2
2	1
3	1

--What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT
	runner_id,
	DATE_PART('minute',AVG(pickup_time-order_time)+INTERVAL '30 seconds') AS min_taken
FROM dot
GROUP BY runner_id;	

OUTPUT
"runner_id"	"min_taken"
3	10
2	20
1	14

--Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH rlt AS (
	SELECT
		c.order_id,
		COUNT(c.order_id) AS num_of_pizza,
		AVG(d.pickup_time-d.order_time) AS time_taken
	FROM cot c INNER JOIN dot d
	ON c.order_id=d.order_id
	GROUP BY c.order_id
)
SELECT
	num_of_pizza,
	AVG(time_taken)
FROM rlt
GROUP BY num_of_pizza;

OUTPUT
"num_of_pizza"	"avg"
3	"00:29:17"
2	"00:18:22.5"
1	"00:12:21.4"

--What was the average distance travelled for each customer?
SELECT
	c.customer_id,
	ROUND(AVG(d.distance_in_km)::NUMERIC,2) AS AVG
FROM dot d INNER JOIN cot c
ON c.order_id=d.order_id
GROUP BY c.customer_id;

OUTPUT
"customer_id"	"avg"
101	20.00
103	23.40
104	10.00
105	25.00
102	16.73

--What was the difference between the longest and shortest delivery times for all orders?
SELECT
	MAX(duration_in_min)-MIN(duration_in_min) AS diff
FROM dot;

OUTPUT
"diff"
30

--What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT
	runner_id,
	order_id,
	ROUND((distance_in_km*60/(duration_in_min))::NUMERIC,2) AS speed
FROM dot;

OUTPUT
"runner_id"	"order_id"	"speed"
1	1	37.50
1	2	44.44
1	3	40.20
2	4	35.10
3	5	40.00
2	7	60.00
2	8	93.60
1	10	60.00

--What is the successful delivery percentage for each runner?
SELECT 
	runner_id,
	(COUNT(distance_in_km)*100/COUNT(runner_id)) AS percentage
FROM rot
GROUP BY runner_id;

OUTPUT
"runner_id"	"percentage"
3	50
2	75
1	100


--C. Ingredient Optimisation
--What are the standard ingredients for each pizza?
SELECT
	pn.pizza_name,
	STRING_AGG(por.topping_name,',')
FROM por INNER JOIN pizza_names pn
ON por.pizza_id=pn.pizza_id
GROUP BY pn.pizza_name;

OUTPUT
"pizza_name"	"string_agg"
"Meatlovers"	"Bacon,BBQ Sauce,Beef,Cheese,Chicken,Mushrooms,Pepperoni,Salami"
"Vegetarian"	"Cheese,Mushrooms,Onions,Peppers,Tomatoes,Tomato Sauce"

--What was the most commonly added extra?
SELECT
	e.extra,
	pt.topping_name,
	COUNT(e.extra)
FROM extras e LEFT JOIN pizza_toppings pt
ON e.extra=pt.topping_id
GROUP BY e.extra,pt.topping_name
ORDER BY count DESC;

OUTPUT
"extra"	"topping_name"	"count"
1	"Bacon"	4
5	"Chicken"	1
4	"Cheese"	1

--What was the most common exclusion?
SELECT
	e.exclusion,
	pt.topping_name,
	COUNT(e.exclusion)
FROM exclusions e LEFT JOIN pizza_toppings pt
ON e.exclusion=pt.topping_id
GROUP BY e.exclusion,pt.topping_name
ORDER BY count DESC;

OUTPUT
"exclusion"	"topping_name"	"count"
4	"Cheese"	4
2	"BBQ Sauce"	1
6	"Mushrooms"	1

--Generate an order item for each record in the customers_orders table in the format of one of the following:
WITH rec AS (
	SELECT
		cot.record_id,
		cot.pizza_id,
		'Extra '||STRING_AGG(CASE WHEN por.topping_id IN (SELECT extra FROM extras WHERE cot.record_id=extras.record_id)
		 	THEN por.topping_name
		 	ELSE NULL
			END,',') AS extra,
		'Exclude '||STRING_AGG(CASE WHEN por.topping_id IN (SELECT exclusion FROM exclusions WHERE cot.record_id=exclusions.record_id)
			   THEN por.topping_name
			   ELSE NULL
			   END,',') AS exclusion
	FROM cot INNER JOIN por
	ON cot.pizza_id=por.pizza_id
	GROUP BY cot.record_id,cot.pizza_id
)
SELECT
	record_id,
	(CASE 
		WHEN rec.extra IS NULL AND rec.exclusion IS NULL THEN pn.pizza_name
		WHEN rec.extra IS NULL THEN pn.pizza_name||':'||rec.exclusion
		WHEN rec.exclusion IS NULL THEN pn.pizza_name||':'||rec.extra
		ELSE pn.pizza_name||':'||rec.extra||'-'||rec.exclusion
		END) AS notes
FROM rec INNER JOIN pizza_names pn
ON rec.pizza_id=pn.pizza_id;

OUTPUT:
"record_id"	"notes"
1	"Meatlovers"
2	"Meatlovers"
3	"Meatlovers"
4	"Vegetarian"
5	"Meatlovers:Exclude Cheese"
6	"Meatlovers:Exclude Cheese"
7	"Vegetarian:Exclude Cheese"
8	"Meatlovers:Extra Bacon"
9	"Vegetarian"
10	"Vegetarian"
11	"Meatlovers"
12	"Meatlovers:Extra Chicken,Bacon-Exclude Cheese"
13	"Meatlovers"
14	"Meatlovers:Extra Cheese,Bacon-Exclude BBQ Sauce,Mushrooms"

--Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
WITH il AS (
	SELECT
		cot.record_id,
		pn.pizza_name,
		CASE WHEN por.topping_id IN (SELECT extra FROM extras WHERE extras.record_id=cot.record_id)
			 THEN '2x'|| por.topping_name
		ELSE por.topping_name
		END AS ing_list
	FROM cot INNER JOIN por
	ON cot.pizza_id=por.pizza_id
	INNER JOIN pizza_names pn
	ON cot.pizza_id=pn.pizza_id
	WHERE por.topping_id NOT IN (SELECT exclusion FROM exclusions WHERE exclusions.record_id=cot.record_id)
)
SELECT
	record_id,
	CONCAT(pizza_name||':'||STRING_AGG(ing_list,',' ORDER BY ing_list)) AS ing_lists
FROM il
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
	CASE WHEN por.topping_id IN ( SELECT extra FROM extras
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
 WHERE por.topping_id NOT IN (SELECT exclusion FROM exclusions
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



