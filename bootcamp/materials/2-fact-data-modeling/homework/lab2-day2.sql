drop table if exists users_cumulated;
create table users_cumulated ( 
	user_id TEXT,
	dates_active DATE[], -- list of dates in the past where the user was active
	date DATE, --the current date for the user
	primary key (user_id,date)
);

insert into users_cumulated
with yesterday as ( 
select * from users_cumulated where date = DATE('2023-01-02')
),
today as (
select cast(user_id as text) as user_id, DATE(cast(event_time as timestamp)) as date_active
from events
where DATE(cast(event_time as timestamp)) = DATE('2023-01-03')
and user_id is not null
group by user_id, DATE(cast(event_time as timestamp)) 
)
select coalesce(t.user_id, y.user_id) as user,
case when y.dates_active is null then array[t.date_active]
	when t.date_active is null then y.dates_active
end as dates_active,
coalesce(t.date_active, y.date + interval '1 day') as date
from today t 
full outer join yesterday y
on t.user_id = y.user_id;

--select * from users_cumulated
--continue
	