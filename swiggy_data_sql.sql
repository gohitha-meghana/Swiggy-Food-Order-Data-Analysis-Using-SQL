select * from swiggy_db.swiggy_data;

-- Data Validation & cleaning
-- Changing column & table names
rename table swiggy_data_1 to swiggy_data;
alter table swiggy_data rename column ï»¿State to State;
alter table swiggy_data rename column `Order Date`to order_date;
alter table swiggy_data rename column `Restaurant Name` to restaurant_name;
alter table swiggy_data rename column `Dish Name` to dish_name ;
alter table swiggy_data rename column `Price (INR)` to price ;
alter table swiggy_data rename column `Rating Count` to rating_count ;

-- Checking Null Values
select 
sum(case when State is null then 1 else 0 end ) as null_State,
sum(case when city is null then 1 else 0 end ) as null_city,
sum(case when order_date is null then 1 else 0 end ) as null_order_date,
sum(case when restaurant_name is null then 1 else 0 end ) as null_restaurant_name,
sum(case when location is null then 1 else 0 end ) as location,
sum(case when category is null then 1 else 0 end ) as null_category,
sum(case when dish_name is null then 1 else 0 end ) as null_dishname,
sum(case when price is null then 1 else 0 end ) as null_price,
sum(case when rating is null then 1 else 0 end ) as null_rating,
sum(case when rating_count is null then 1 else 0 end ) as null_rating_count 
from swiggy_db.swiggy_data;

-- Empty or Blank Srings
select 
* from swiggy_data where State = " " or City = " " or restaurant_name = " " or Location = " " or Category = " " or dish_name = " " ; 

-- Duplicate Detection 
select 
State,City,order_date,restaurant_name,Location,Category,dish_name,price,Rating,rating_count,count(*) as count
from swiggy_data
group by State,City,order_date,restaurant_name,Location,Category,dish_name,price,Rating,rating_count
having count(*)>1;

-- Delete Duplication
with cte as (select * , 
row_number() over(partition by State,City,order_date,restaurant_name,Location,Category,dish_name,price,Rating,rating_count 
order by(select null)) as rn
from swiggy_data)
select * from cte where rn>1;

-- Create Schema
-- Dimention Table
-- Dim_Date Table
create table dim_date(
date_id int auto_increment primary key, full_date date, year int, month int, month_name varchar(20), quarter int, day int, week int);

-- Dim_Location
create table dim_location (
location_id int auto_increment primary key, state varchar(100), city varchar(100),location varchar(200) );

-- Dim_Restaurant
create table dim_restaurant(
restaurant_id int auto_increment primary key, restaurant_name varchar(200) );

-- dim_Category
create table dim_category(
category_id int auto_increment primary key, category varchar(200) );

-- dim_Dish
create table dim_dish(
dish_id int auto_increment primary key, dish_name varchar(200));

-- Fact_Table 
create table fact_orders(
order_id int auto_increment primary key,

date_id int,
price decimal(10,2),
rating decimal(5,2),
rating_count int,

location_id int,
restaurant_id int,
category_id int,
dish_id int,

foreign key (date_id) references dim_date(date_id),
foreign key (location_id) references dim_location(location_id),
foreign key (restaurant_id) references dim_restaurant(restaurant_id),
foreign key (category_id) references dim_category(category_id),
foreign key (dish_id) references dim_dish(dish_id)
);

-- Insert data in tables
-- dim_table
insert into dim_date(full_date ,year,month,month_name,quarter,day,week)
select distinct str_to_date(order_date,'%d-%m-%Y'),
 year(str_to_date(order_date,'%d-%m-%Y')), 
 month(str_to_date(order_date,'%d-%m-%Y')),
 monthname(str_to_date(order_date,'%d-%m-%Y')),
 quarter(str_to_date(order_date,'%d-%m-%Y')),
 day(str_to_date(order_date,'%d-%m-%Y')),
 week(str_to_date(order_date,'%d-%m-%Y'))
from swiggy_data where order_date is not null;

-- dim_location
insert into dim_location(state,city,location)
select distinct state,city,location from swiggy_data ;

-- dim_restaurant
insert into dim_restaurant(restaurant_name)
select distinct restaurant_name from swiggy_data;

-- dim category
insert into dim_category(category)
select distinct category from swiggy_data;

-- dim_dish
insert into dim_dish(dish_name)
select distinct dish_name from swiggy_data;

-- fact table
insert into fact_orders(
date_id,price,rating,rating_count,location_id,restaurant_id,category_id,dish_id)
select dd.date_id,s.price,s.rating,s.rating_count, dl.location_id,dr.restaurant_id,dc.category_id,dish.dish_id
from swiggy_data s 
join dim_date dd on dd.full_date = str_to_date(s.order_date,"%d-%m-%Y")
join  dim_location dl on dl.state = s.state
and dl.city = s.city
and dl.location = s.location 
join dim_restaurant dr on dr.restaurant_name=s.restaurant_name
join dim_category dc on dc.category = s.category
join dim_dish dish on dish.dish_name = s.dish_name;

select * from fact_orders f
join dim_date d on f.date_id=d.date_id
join dim_location l on f.location_id= l.location_id
join dim_restaurant r on f.restaurant_id = r.restaurant_id
join dim_category c on f.category_id = c.category_id
join dim_dish di on f.dish_id = di.dish_id;

-- KPI's
-- Total Orders
select count(*) as Total_Orders from fact_orders;

-- Total Revenue (INR Million)
select concat(round(sum(cast(price as decimal(15,2)))/1000000,2)," ","INR Million") as Toatal_Revenue from fact_orders;

-- Dish Price
select concat(round(avg(cast(price as decimal(15,2))),2)," ","INR") as Avg_Dish_Price from fact_orders;

-- Average Rating
select  round(avg(rating),1) as Avg_rating from fact_orders;

-- Deep Drive Business analysis
-- Monthly order Trends
select d.year,d.month,d.month_name,count(*) as Total_Orders
from fact_Orders f join dim_date d on f.date_id=d.date_id
group by d.year,d.month,d.month_name 
order by count(*) desc;

-- Quarterly Trend
select d.year,d.quarter,count(*) as Total_Orders
from fact_Orders f join dim_date d on f.date_id=d.date_id
group by d.year,d.quarter;

-- Yearly Trend
select d.year,count(*) as Total_Orders
from fact_Orders f join dim_date d on f.date_id=d.date_id
group by d.year;

-- Orders by day of Week (Mon-Sun)
select dayname(d.full_date) as day_name, count(*) as total_orders
from fact_orders f join dim_date d on f.date_id =d.date_id
group by dayname(d.full_date),dayofweek(d.full_date) order by dayofweek(d.full_date);

-- top 10 Dish's by order
select dish.dish_name,count(*) as total_count
from fact_orders f join dim_dish dish on dish.dish_id=f.dish_id 
group by dish.dish_name 
order by count(*) desc limit 10;

-- top categories by order volume
select c.category,count(*) as total_count
from fact_orders f join dim_category c on c.category_id = f.category_id 
group by c.category
order by count(*) desc ;

-- top 10 Restaurant's by Sales
select r.restaurant_name,count(*) as total_count
from fact_orders f join dim_restaurant r on r.restaurant_id=f.restaurant_id 
group by r.restaurant_name 
order by count(*) desc limit 10;

-- Total orders by price range
select 
case 
when cast(price as decimal(10,2)) < 100 then "under 100"
when cast(price as decimal(10,2)) between 100 and 199 then "100-199"
when cast(price as decimal(10,2)) between 200 and 299 then "200 - 299"
when cast(price as decimal(10,2)) between 300 and 499 then "300 - 499"
else "500+"
end as price_range,
count(*) as total_orders
from fact_orders
group by 
case
when cast(price as decimal(10,2)) < 100 then "under 100"
when cast(price as decimal(10,2)) between 100 and 199 then "100-199"
when cast(price as decimal(10,2)) between 200 and 299 then "200 - 299"
when cast(price as decimal(10,2)) between 300 and 499 then "300 - 499"
else "500+"
end
order by total_orders desc;

-- rating count distribution(1-5)
select rating ,count(*) as total_ratings from fact_orders group by rating order by count(*) desc;













