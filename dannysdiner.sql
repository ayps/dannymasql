
--What is the total amount each customer spent at the restaurant?
SELECT customer_id AS customers, sum(price) as total_amount_spent
FROM dannys_diner.sales INNER JOIN dannys_diner.menu
on sales.product_id=menu.product_id
GROUP BY customer_id
ORDER BY customer_id;

OUTPUT

"customers"	"total_amount_spent"
"A"	76
"B"	74
"C"	36

--How many days has each customer visited the restaurant?
SELECT customer_id as customers, COUNT(DISTINCT(order_date))as frequency_of_visits
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;

OUTPUT

"customers"	"frequency_of_visits"
"A"	4
"B"	6
"C"	2

--What was the first item from the menu purchased by each customer?
WITH ranks AS (
	SELECT 
		customer_id as customers,
		product_name as first_item_purchased,
		DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) as ranking
	FROM dannys_diner.sales INNER JOIN dannys_diner.menu
	ON sales.product_id = menu.product_id
)
SELECT customers, first_item_purchased
FROM ranks
WHERE ranking = 1;

OUTPUT

"customers"	"first_item_purchased"
"A"	"curry"
"A"	"sushi"
"B"	"curry"
"C"	"ramen"
"C"	"ramen"

--What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_name as most_purchased_item, COUNT(sales.product_id) AS frequency_purchased
FROM dannys_diner.sales INNER JOIN dannys_diner.menu
ON sales.product_id=menu.product_id
GROUP BY sales.product_id, product_name
ORDER BY frequency_purchased DESC
LIMIT 1;

OUTPUT

"most_purchased_item"	"frequency_purchased"
"ramen"	8

--Which item was the most popular for each customer?
WITH popular AS (
	SELECT 
		customer_id AS customers,
		product_id,
		DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(product_id) DESC) AS most_popular
	FROM dannys_diner.sales
	GROUP BY customer_id,product_id
)
SELECT 
	customers, 
	product_name as most_popular_item
FROM popular INNER JOIN dannys_diner.menu
ON popular.product_id = menu.product_id
WHERE most_popular=1
ORDER BY customers;

OUTPUT

"customers"	"most_popular_item"
"A"	"ramen"
"B"	"sushi"
"B"	"curry"
"B"	"ramen"
"C"	"ramen"

--Which item was purchased first by the customer after they became a member?
WITH join_date AS(
	SELECT 
		sales.customer_id AS customers,
		product_id,
		order_date,
		join_date,
		RANK() OVER(PARTITION BY sales.customer_id ORDER BY order_date) as rankss
	FROM dannys_diner.sales INNER JOIN dannys_diner.members
	ON sales.customer_id=members.customer_id
	WHERE order_date>=join_date
)
SELECT 
	customers, 
	product_name as first_item_purchased
FROM join_date INNER JOIN dannys_diner.menu
on join_date.product_id=menu.product_id
WHERE rankss=1
ORDER BY customers;

OUTPUT

"customers"	"first_item_purchased"
"A"	"curry"
"B"	"sushi"

--Which item was purchased just before the customer became a member?
WITH join_date AS(
	SELECT 
		sales.customer_id AS customers,
		product_id,
		order_date,
		join_date,
		RANK() OVER(PARTITION BY sales.customer_id ORDER BY order_date DESC) as rankss
	FROM dannys_diner.sales INNER JOIN dannys_diner.members
	ON sales.customer_id=members.customer_id
	WHERE order_date<join_date
)
SELECT 
	customers, 
	product_name as first_item_purchased
FROM join_date INNER JOIN dannys_diner.menu
on join_date.product_id=menu.product_id
WHERE rankss=1
ORDER BY customers;

OUTPUT

"customers"	"first_item_purchased"
"A"	"sushi"
"A"	"curry"
"B"	"sushi"

--What is the total items and amount spent for each member before they became a member?
SELECT 
	sales.customer_id AS customers,
	SUM(price) AS total_spent
FROM dannys_diner.sales INNER JOIN dannys_diner.menu
ON sales.product_id=menu.product_id
INNER JOIN dannys_diner.members
on sales.customer_id=members.customer_id
WHERE order_date<join_date
GROUP BY customers
ORDER BY customers;

OUTPUT

"customers"	"total_spent"
"A"	25
"B"	40

--If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points AS (
	SELECT 
		customer_id as customers,
		product_id,
		CASE WHEN product_id=1 THEN 20
		ELSE 10
		END AS points
	FROM dannys_diner.sales
)
SELECT 
	customers, 
	SUM(points*price) AS points_collected
FROM points INNER JOIN dannys_diner.menu
ON points.product_id=menu.product_id
GROUP BY customers
ORDER BY customers;

OUTPUT

"customers"	"points_collected"
"A"	860
"B"	940
"C"	360

--In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH points AS(
	SELECT
		sales.customer_id AS customers,
		product_id,
		order_date,
		join_date,
		CASE WHEN product_id=1 THEN 20
			 WHEN order_date - join_date+6>=0 THEN 20 
		ELSE 10 
		END AS points
	FROM dannys_diner.sales INNER JOIN dannys_diner.members
	ON sales.customer_id=members.customer_id
)
SELECT 
	customers, 
	SUM(points*price) AS points_collected
FROM points INNER JOIN dannys_diner.menu
ON points.product_id=menu.product_id
WHERE order_date<='2021-01-31'
GROUP BY customers
ORDER BY customers;

OUTPUT

"customers"	"points_collected"
"A"	1520
"B"	940
