**What is the total amount each customer spent at the restaurant?**

```sql
select customer_id, sum(price) as total_amount_spent
from dannys_diner.sales inner join dannys_diner.menu
on sales.product_id=menu.product_id
group by customer_id
order by total_amount_spent desc;
