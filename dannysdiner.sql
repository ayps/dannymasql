--schema sql
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

--What is the total amount each customer spent at the restaurant?
SELECT
	s.customer_id,
	SUM(m.price) AS tot_spent
FROM sales s INNER JOIN menu m
ON s.product_id=m.product_id
GROUP BY s.customer_id;

OUTPUT
"customer_id"	"tot_spent"
"B"	74
"C"	36
"A"	76

--How many days has each customer visited the restaurant?
SELECT
	customer_id,
	COUNT(DISTINCT order_date) AS freq_vis
FROM sales
GROUP BY customer_id;

OUTPUT
"customer_id"	"freq_vis"
"A"	4
"B"	6
"C"	2

--What was the first item from the menu purchased by each customer?
WITH ranks AS (
	SELECT
		s.customer_id,
		m.product_name,
		DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS ranks
	FROM sales s INNER JOIN menu m
	ON s.product_id=m.product_id
)
SELECT
	customer_id,
	product_name
FROM ranks
WHERE ranks=1;

OUTPUT
"customer_id"	"product_name"
"A"	"curry"
"A"	"sushi"
"B"	"curry"
"C"	"ramen"
"C"	"ramen"

--What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
	m.product_name,
	COUNT(s.product_id) AS most_pur
FROM sales s INNER JOIN menu m
ON s.product_id=m.product_id
GROUP BY m.product_name
ORDER BY most_pur DESC
LIMIT 1;

OUTPUT
"product_name"	"most_pur"
"ramen"	8

--Which item was the most popular for each customer?
WITH pop AS (
	SELECT
		s.customer_id,
		m.product_name AS pop_item,
		DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS pop
	FROM sales s INNER JOIN menu m
	ON s.product_id=m.product_id
	GROUP BY s.customer_id,pop_item
)
SELECT
	customer_id,
	pop_item
FROM pop
WHERE pop=1;

OUTPUT
"customer_id"	"pop_item"
"A"	"ramen"
"B"	"sushi"
"B"	"curry"
"B"	"ramen"
"C"	"ramen"

--Which item was purchased first by the customer after they became a member?
WITH mem AS (
	SELECT
		s.customer_id,
		m.product_name AS fir_pur,
		DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS ranks
	FROM sales s INNER JOIN menu m
	ON s.product_id=m.product_id
	INNER JOIN members me
	ON s.customer_id=me.customer_id
	WHERE s.order_date>me.join_date
)
SELECT
	customer_id,
	fir_pur
FROM mem
WHERE ranks=1;

OUTPUT
"customer_id"	"fir_pur"
"A"	"ramen"
"B"	"sushi"

--Which item was purchased just before the customer became a member?
WITH mem AS (
	SELECT
		s.customer_id,
		m.product_name AS las_pur,
		DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS ranks
	FROM sales s INNER JOIN menu m
	ON s.product_id=m.product_id
	INNER JOIN members me
	ON s.customer_id=me.customer_id
	WHERE s.order_date<me.join_date
)
SELECT
	customer_id,
	las_pur
FROM mem
WHERE ranks=1;

OUTPUT
"customer_id"	"las_pur"
"A"	"sushi"
"A"	"curry"
"B"	"sushi"

--What is the total items and amount spent for each member before they became a member?
SELECT
	s.customer_id,
	COUNT(s.product_id) AS tot_items,
	SUM(m.price) AS tot_spent
FROM sales s INNER JOIN menu m
ON s.product_id=m.product_id
INNER JOIN members me
ON s.customer_id=me.customer_id
WHERE s.order_date<me.join_date
GROUP BY s.customer_id;

OUTPUT
"customer_id"	"tot_items"	"tot_spent"
"B"	3	40
"A"	2	25

--If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT
	s.customer_id,
	SUM(CASE WHEN m.product_name LIKE 'sus%'
	   		 THEN m.price*20
	   		 ELSE m.price*10
	   	END) AS points
FROM sales s INNER JOIN menu m
ON s.product_id=m.product_id
GROUP BY s.customer_id;

OUTPUT
"customer_id"	"points"
"B"	940
"C"	360
"A"	860

--In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT
	s.customer_id,
	SUM(CASE WHEN m.product_name LIKE 'sus%'
			 THEN m.price*20
			 WHEN s.order_date>me.join_date+6
			 THEN m.price*20
			 ELSE m.price*10
		END) AS points
FROM sales s INNER JOIN menu m
ON s.product_id=m.product_id
INNER JOIN members me
ON s.customer_id=me.customer_id
WHERE s.order_date<='2021-01-31'
GROUP BY s.customer_id;

OUTPUT
"customer_id"	"points"
"A"	860
"B"	940
