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
**cleaning runners orders table**
```sql
create temporary table runner_orders_temporary as (
	select order_id,
		   runner_id,
		   case when pickup_time='' or pickup_time='null' then null
		   		else pickup_time
		   end as pickup_time_cleaned,
		   case when distance='' or distance='null' then null
				else regexp_replace(distance,'[a-z]+','')
		   end as  distance_cleaned,
		   case when duration='' or distance='null' then null
				else regexp_replace(duration,'[a-z]+','')
		   end as duration_cleaned,
		   case when cancellation ='null' or cancellation='' then null
				else cancellation
		   end as cancellation_cleaned
	from pizza_runner.runner_orders
);
```
**How many pizzas were ordered?**
```sql
select count(order_id) as total_pizzas_orders from customer_orders_temporary;
```
**How many unique customer orders were made?**
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
**What was the total volume of pizzas ordered for each hour of the day?**
```sql
select extract(hour from order_time) as hourly_data, count(pizza_id)
from customer_orders_temporary
group by hourly_data
order by hourly_data;
```
**What was the volume of orders for each day of the week?**
```sql
select to_char(order_time,'day')as day_of_week,
	   count(pizza_id) as pizza_count
from customer_orders_temporary
group by day_of_week
order by day_of_week;
```
**What was the volume of orders for each day of the week?**
```sql
with days as (
	select to_char(order_time,'day')as day_of_week,
	   count(pizza_id) as pizza_count
from customer_orders_temporary
group by day_of_week
)
SELECT * from days
order by
    CASE
        WHEN day_of_week like 'sun%' THEN 1
        WHEN day_of_week like 'mon%' THEN 2
        WHEN day_of_week like 'tues%' THEN 3
        WHEN day_of_week like 'wedne%' THEN 4
        WHEN day_of_week like 'thurs%' THEN 5
        WHEN day_of_week like 'frid%' THEN 6
        WHEN day_of_week like 'satur%' THEN 7
        ELSE 0
    END desc;
```
***Section B***


**How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)**
```sql
select extract(week from registration_date+3) as week_of_the_year,count(runner_id) from pizza_runner.runners
group by week_of_the_year
order by week_of_the_year;
```
**altering data type of pickup_time_cleaned to timestamp**
```sql
alter table runner_orders_temporary
alter column pickup_time_cleaned type timestamp using pickup_time_cleaned::timestamp without time zone;
```
**What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?**
```sql
select runner_orders_temporary.runner_id,date_trunc ('minute', (sum(pickup_time_cleaned-order_time)/count(runner_id))+interval '30 second') as avg_time
from runner_orders_temporary inner join customer_orders_temporary
on runner_orders_temporary.order_id=customer_orders_temporary.order_id
where cancellation_cleaned is null
group by runner_orders_temporary.runner_id;
```
**Is there any relationship between the number of pizzas and how long the order takes to prepare?**
```sql
with table_1 as (
	
select customer_orders_temporary.order_id,
	   date_trunc ('seconds', (sum(pickup_time_cleaned-order_time)/count(customer_orders_temporary.order_id))) as avg_time,
	   count(customer_orders_temporary.order_id) as number_of_pizzas_ordered
from runner_orders_temporary inner join customer_orders_temporary
on runner_orders_temporary.order_id=customer_orders_temporary.order_id
where cancellation_cleaned is null
group by runner_orders_temporary.runner_id, customer_orders_temporary.order_id
)
select number_of_pizzas_ordered, avg(avg_time)
from table_1
group by number_of_pizzas_ordered 
order by number_of_pizzas_ordered desc;
```
**altering data type in runner_orders_temporary table**
```sql
alter table runner_orders_temporary
alter column distance_cleaned type float using distance_cleaned::float,
alter column duration_cleaned type float using duration_cleaned::float;
```
**What was the average distance travelled for each customer?**
```sql
select customer_id, cast(avg(distance_cleaned) as numeric(10,2))as average_distance_travelled
from runner_orders_temporary inner join customer_orders_temporary
on runner_orders_temporary.order_id=customer_orders_temporary.order_id
group by customer_id
order by average_distance_travelled;
```
**What was the difference between the longest and shortest delivery times for all orders?**
```sql
select cast(max(duration_cleaned)-min(duration_cleaned) as integer) as delivery_time_difference from runner_orders_temporary;
```



