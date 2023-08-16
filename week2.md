***Section A***

**cleaning customers orders table**
```sql
create temporary table customer_orders_temporary as (
	select order_id,
		   customer_id,
		   pizza_id,
		   case when exclusions=''or exclusions='null' then null
				else exclusions
		   end as exclusions_cleaned,
		   case when extras='' or extras='null' then null
				else extras
		   end as extras_cleaned,
		   order_time
	from pizza_runner.customer_orders
);
```
**How many pizzas were ordered?**
```sql
select count(order_id) as total_pizzas_orders from customer_orders_temporary;
```
***How many unique customer orders were made?**
```sql
select customer_id, count(distinct(order_id)) as unique_customer_orders 
from customer_orders_temporary
group by customer_id;
```
**How many successful orders were delivered by each runner?**
```sql
select runner_id, count(order_id) as delivery_count
from runner_orders_temporary
where distance_cleaned is not null
group by runner_id
order by delivery_count desc;
```
**How many of each type of pizza was delivered?**
```sql
select pizza_name, count(customer_orders_temporary.pizza_id)
from customer_orders_temporary inner join pizza_runner.pizza_names
on customer_orders_temporary.pizza_id=pizza_names.pizza_id
inner join runner_orders_temporary
on customer_orders_temporary.order_id=runner_orders_temporary.order_id
where distance_cleaned is not null
group by pizza_name;
```
**How many Vegetarian and Meatlovers were ordered by each customer?**
```sql
select customer_id, pizza_name, count(order_id)
from customer_orders_temporary inner join pizza_runner.pizza_names
on customer_orders_temporary.pizza_id=pizza_names.pizza_id
group by customer_id,pizza_name
order by customer_id;
```
**What was the maximum number of pizzas delivered in a single order?**
```sql
select customer_orders_temporary.order_id, count(customer_orders_temporary.pizza_id) as pizzas_delivered
from customer_orders_temporary inner join runner_orders_temporary 
on customer_orders_temporary.order_id=runner_orders_temporary.order_id
group by customer_orders_temporary.order_id
order by pizzas_delivered desc
limit 1;
```
**For each customer, how many delivered pizzas had at least 1 change and how many had no changes?**
```sql
select customer_orders_temporary.customer_id,
	   sum(case when exclusions_cleaned is null and extras_cleaned is null then 1
		  		else 0
		   end) as pizzas_with_no_change,
	   sum(case when extras_cleaned is not null or exclusions_cleaned is not null then 1
		  		else 0
		   end) as pizzas_with_atleast_1_change
from customer_orders_temporary inner join runner_orders_temporary
on customer_orders_temporary.order_id=runner_orders_temporary.order_id
where distance_cleaned is not null
group by customer_orders_temporary.customer_id
order by customer_orders_temporary.customer_id;
```
**How many pizzas were delivered that had both exclusions and extras?**
```sql
select customer_orders_temporary.customer_id,
		   sum(case when extras_cleaned is not null and exclusions_cleaned is not null then 1
		  		else 0
		   end) as pizzas_with_both_exlusions_and_extras
from customer_orders_temporary inner join runner_orders_temporary
on customer_orders_temporary.order_id=runner_orders_temporary.order_id
where distance_cleaned is not null
group by customer_orders_temporary.customer_id
order by customer_orders_temporary.customer_id;
```


