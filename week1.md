
**What is the total amount each customer spent at the restaurant?**

```sql
select customer_id, sum(price) as total_amount_spent
from dannys_diner.sales inner join dannys_diner.menu
on sales.product_id=menu.product_id
group by customer_id
order by total_amount_spent desc;
```
**How many days has each customer visited the restaurant?**

```sql
select customer_id,count(distinct(order_date)) as no_of_visits
from dannys_diner.sales
group by customer_id
order by no_of_visits desc;
```
**What was the first item from the menu purchased by each customer?**
```sql
with first_item as (
	select sales.customer_id,
		   menu.product_name,
		   sales.order_date,
		   dense_rank()over(partition by sales.customer_id order by sales.order_date) as ranks
	from dannys_diner.menu inner join dannys_diner.sales
	on menu.product_id=sales.product_id
)
select customer_id,product_name,order_date
from first_item
where ranks =1
group by product_name,customer_id,order_date;
```
**What is the most purchased item on the menu and how many times was it purchased by all customers?**
```sql
select menu.product_name, count(sales.product_id) as most_purchased_item
from dannys_diner.menu inner join dannys_diner.sales
on menu.product_id=sales.product_id
group by product_name
limit 1;
```
**Which item was the most popular for each customer?**
```sql
with most_popular as (
	select sales.customer_id,
		   menu.product_name,
		   count(sales.product_id) as number_of_times_purchased,
		   dense_rank() over (partition by customer_id order by (count(sales.product_id))desc) as ranks
 	from dannys_diner.sales inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	group by sales.customer_id,menu.product_name
)
select customer_id, product_name, number_of_times_purchased
from most_popular
where ranks=1;
```
**Which item was purchased first by the customer after they became a member?**
```sql
with first_purchase as (
	select sales.customer_id,
		   menu.product_name,
		   dense_rank() over (partition by sales.customer_id order by sales.order_date) as ranks
	from dannys_diner.sales inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	inner join dannys_diner.members
	on sales.customer_id=members.customer_id
	where sales.order_date>members.join_date
)
select customer_id,product_name
from first_purchase
where ranks=1;
```
**Which item was purchased just before the customer became a member?**
```sql
with first_purchase as (
	select sales.customer_id,
		   menu.product_name,
		   row_number() over (partition by sales.customer_id order by sales.order_date desc) as ranks
	from dannys_diner.sales inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	inner join dannys_diner.members
	on sales.customer_id=members.customer_id
	where sales.order_date<members.join_date
)
select customer_id,product_name
from first_purchase
where ranks=1;
```
**What are the total items and amount spent for each member before they became a member?**
```sql
select sales.customer_id, 
	   count(sales.product_id) as total_items_purchased,
	   sum(menu.price) as total_amount_spent
from dannys_diner.sales inner join dannys_diner.menu
on sales.product_id=menu.product_id
inner join dannys_diner.members
on sales.customer_id=members.customer_id
where sales.order_date<members.join_date
group by sales.customer_id;
```
**If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?**
```sql
with points_earned as (
	select sales.customer_id,
		   sum(case when sales.product_id=1 then menu.price*20
				else menu.price*10
		   end) as points_earned
	from dannys_diner.sales inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	group by sales.customer_id
)
select * from points_earned
order by customer_id;
```
**In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customers A and B have at the end of January?**
```sql
with dates as (
	select customer_id,
		   join_date+6 as start_date,
	       '2021-01-31'::date as end_date
	from dannys_diner.members
),
points as (
	select sales.customer_id,
		   sum (case when sales.product_id=1 then price*20
			   		 when sales.order_date between start_date and end_date then price*20
			   		 else price*10
			    end) as points_earned
	from dannys_diner.sales inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	inner join dates on sales.customer_id=dates.customer_id
	group by sales.customer_id
)
select * from points;
```
**this is my question - In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customers A,B and C have at the end of January?**
```sql
with dates as (
	select customer_id,
		   join_date+6 as start_date,
	       '2021-01-31'::date as end_date
	from dannys_diner.members
),
points as (
	select sales.customer_id,
		   sum (case when sales.product_id=1 then price*20
			   		 when dates.customer_id is not null and sales.order_date between start_date and end_date then price*20
			   		 else price*10
			    end) as points_earned
	from dannys_diner.sales inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	left join dates on sales.customer_id=dates.customer_id
	group by sales.customer_id
)
select * from points;
```
**bonus question - 1**
```sql
select sales.customer_id,
	   sales.order_date,
	   menu.product_name,
	   menu.price,
	   case when members.join_date>sales.order_date then 'N'
	   		when members.join_date<=sales.order_date then 'Y'
			else 'N'
	   end as members
from dannys_diner.sales left join dannys_diner.menu
on sales.product_id=menu.product_id
left join dannys_diner.members on sales.customer_id=members.customer_id
order by sales.customer_id, sales.order_date;
```
**bonus question -2**
```sql
with members as (
	select sales.customer_id,
		   sales.order_date,
		   menu.product_name,
		   menu.price,
		   case when members.join_date>sales.order_date then 'N'
				when members.join_date<=sales.order_date then 'Y'
				else 'N' 
		   end as members
	from dannys_diner.sales left join dannys_diner.members
	on sales.customer_id=members.customer_id
	inner join dannys_diner.menu
	on sales.product_id=menu.product_id
	order by customer_id, order_date
)
select *,
	   case when members = 'N' then Null
	   		else dense_rank() over(partition by customer_id,members order by order_date)
	   end as rankings
from members;
```

