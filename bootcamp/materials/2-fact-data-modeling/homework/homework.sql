--Homework
--- A query to deduplicate `game_details` from Day 1 so there's no duplicates
with deduped as (
	select g.game_date_est,g.season, g.home_team_id,gd.*, row_number() over (partition by gd.game_id, team_id, player_id order by g.game_date_est) as row_num
	from game_details gd
	join games g on gd.game_id = g.game_id
)
select * from deduped where row_num=1

/*
 - A DDL for an `user_devices_cumulated` table that has:
  - a `device_activity_datelist` which tracks a users active days by `browser_type`
  - data type here should look similar to `MAP<STRING, ARRAY[DATE]>`
    - or you could have `browser_type` as a column with multiple rows for each user (either way works, just be consistent!)
 */
drop table if exists users_cumulated;
create table users_cumulated ( 
	user_id TEXT,
	device_id real,
	dates_active DATE[], -- list of dates in the past where the user was active
	date DATE, --the current date for the user
	primary key (user_id,device_id,date)
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

--- A cumulative query to generate `device_activity_datelist` from `events`

--- A `datelist_int` generation query. Convert the `device_activity_datelist` column into a `datelist_int` column 

--- A DDL for `hosts_cumulated` table 
-- a `host_activity_datelist` which logs to see which dates each host is experiencing any activity

--- The incremental query to generate `host_activity_datelist`

/*
- A monthly, reduced fact table DDL `host_activity_reduced`
   - month
   - host
   - hit_array - think COUNT(1)
   - unique_visitors array -  think COUNT(DISTINCT user_id) 
*/


--- An incremental query that loads `host_activity_reduced` - day-by-day