-- To view the table's data
select * from credit_card_transactions;

-- To change the string_date format to default "YYYY-MM-DD" from it's default format.
update credit_card_transactions
set Date=str_to_date(Date, "%d-%m-%Y");

-- To modify the datatype of `Date` column into date datatype
alter table credit_card_transactions
modify Date date;

-- Eliminate the Country name from the city table
update credit_card_transactions
set city = left(city, locate(',', city)-1);

-- It Describes about the table's data. Like: column datatypes, null_values, etc.
describe credit_card_transactions;

-- Changing the Columns names into lowercase 
alter table credit_card_transactions
rename column `exp_type` to spend_type;



-- Basic Data Exploration


-- i) First & Last day of transaction in the database
select min(transaction_date), max(transaction_date) from credit_card_transactions;	-- 2013-10-04 to 2015-05-26

-- ii) Types of Credit cards
select distinct card_type from credit_card_transactions;	-- Gold, Platinum, Silver, Signature

-- iii) Types of spending through Credit Card
select distinct spend_type from credit_card_transactions;		-- Bills, Food, Entertainment, Grocery, Fuel, Travel



-- Data Analysis using multiple cases


-- Q1- write a query to print top 5 cities with highest spends and their percentage contribution of total credit card spends 
with city_spnd as (
	select city, sum(amount) AS total_amount
	from credit_card_transactions
	group by city
),
total_spnd as (
	select sum(amount) as total_spent 
	from credit_card_transactions
)

select city_spnd.*, 
	total_spent, ROUND(city_spnd.total_amount*1.0/total_spnd.total_spent*100, 3) as percentage_contribution
from city_spnd inner join total_spnd on 1=1
order by total_amount desc
limit 5;


-- Q2- write a query to print highest spend month and amount spent in that month for each card type
with monthly_spnd as (
select card_type,
	extract(year from transaction_date) as yr, 
	extract(month from transaction_date) as mth, 
    sum(amount) as total_spend
from credit_card_transactions
group by 1,2,3
order by 1, 4 desc
),
ranks as (
	select *, rank() over(partition by card_type order by total_spend) rn
    from monthly_spnd
)

select r.card_type, r.yr, r.mth, r.total_spend 
from ranks as r 
where rn=1;


-- Q3- write a query to print the transaction details(all columns from the table) for each card type when
-- it reaches a cumulative of 1,000,000 total spends(We should have 4 rows in the o/p one for each card type)
with cumulative as (
	select *, sum(amount) over(partition by card_type order by transaction_date, transaction_id) as total_spend
from credit_card_transactions
),
ranks as (
select *, 
rank() over(partition by card_type order by total_spend) as rn
from cumulative
where total_spend >= 1000000)

select * from ranks 
where rn=1;


-- Q4- write a query to find city which had lowest percentage spend for gold card type
with city_spend as (
select *,
	sum(amount) over(partition by city) as total_spend
from credit_card_transactions
where card_type = "Gold"),
total_spent as (
	select sum(amount) as total_spending_amount from credit_card_transactions
),
spending_per as (
	select city, sum(total_spend*1.0/total_spending_amount*100) as gold_ratio
    from city_spend, total_spent
    group by city
)

select * from spending_per
order by gold_ratio limit 1;


-- Q5- write a query to print 3 columns:  
-- city, highest_spend_type , lowest_spend_type (example format : Delhi , bills, Fuel)
with city_spend as (
select 
	city, 
	spend_type,
	sum(amount) as total_amount
from credit_card_transactions
group by city, spend_type
),
rankings as (
select *,
	rank() over(partition by city order by total_amount desc) as rn_desc,
    rank() over(partition by city order by total_amount asc) as rn_asc
from city_spend
)

select city,
	max(case when rn_desc = 1 then spend_type end) as highest_exp_type,
    min(case when rn_asc = 1 then spend_type end) as lowest_exp_type
from rankings
group by city; 


-- Q6- write a query to find percentage contribution of spends by females for each spend type
select spend_type,
	sum(case when gender='F' then amount else 0 end)*1.0/sum(amount)*100 as percentage_female_contribution
from credit_card_transactions
group by spend_type
order by percentage_female_contribution desc;


-- Q7- which card_type and spend_type combination saw highest month over month growth in Jan-2014
with card_spend_type as (
select
	card_type,
    spend_type, 
    extract(year from transaction_date) as yr,
    extract(month from transaction_date) as mth,
    sum(amount) as total_spend
from credit_card_transactions
group by 1, 2, 3, 4
),
prev_mth as (
select *,
	lag(total_spend, 1) over(partition by card_type, spend_type order by yr, mth) as prev_month_spend
from card_spend_type
)

select *,
	(total_spend-prev_month_spend*1.0)/prev_month_spend*100 as MoM_growth
from prev_mth
where prev_month_spend is not null and yr=2014 and mth = 1
order by MoM_growth desc;


-- Q8- During weekends which city has highest total spend to total no of transcations ratio 
-- select transaction_date, dayofweek(transaction_date) in (1, 7)
with weekend_city_spend as (
select 
	city, 
    sum(amount) as total_spend,
    COUNT(*) AS total_transactions
from credit_card_transactions
where dayofweek(transaction_date) in (1, 7)
group by city
)

select *, total_spend/count(*) as ratio 
from weekend_city_spend
group by city
order by ratio desc;


-- 9- which city took least number of days to reach its
-- 500th transaction after the first transaction in that city;
with cte as (
select *,
	row_number() over(partition by city order by transaction_date, transaction_id) as rn
from credit_card_transactions
)

select 
	city, max(transaction_date), min(transaction_date),
    datediff(max(transaction_date), min(transaction_date)) as days_took_to_500_trans
from cte
where rn=1 or rn=500
group by city
having count(city) = 2
order by days_took_to_500_trans
limit 1;



/*
6931	Bengaluru	2013-10-04	Gold	Fuel	F	236037	1
9570	Bengaluru	2013-12-24	Gold	Food	F	92361	500

datediff(2013-12-24 -- 2013-10-04) Bengaluru took 81 days to complete 500 transactions.
*/