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
--- A cumulative query to generate `device_activity_datelist` from `events`
--- A `datelist_int` generation query. Convert the `device_activity_datelist` column into a `datelist_int` column 
DROP TABLE IF EXISTS user_devices_cumulated;
CREATE TABLE user_devices_cumulated (
    user_id TEXT,
    device_activity_datelist JSONB,
    device_activity_datelist_int JSONB,
    snap_dt TIMESTAMP,
    PRIMARY KEY (user_id, snap_dt)
);

insert into user_devices_cumulated
WITH event_devices AS (
    SELECT 
        COALESCE(e.user_id, '0') AS user_id, 
        COALESCE(e.device_id, '0') as device_id, 
        d.browser_type,
        CAST(e.event_time AS DATE) AS event_date 
    FROM events e 
    LEFT JOIN devices d ON COALESCE(e.device_id, '0') = COALESCE(d.device_id, '0')
    GROUP BY COALESCE(e.user_id, '0'), COALESCE(e.device_id, '0'), d.browser_type, e.event_time
),
agg_browser AS (
    SELECT 
        user_id,
        device_id,
        browser_type,
        ARRAY_AGG(DISTINCT event_date ORDER BY event_date) AS active_dates,
        ARRAY_AGG(
            DISTINCT CAST(to_char(event_date, 'YYYYMMDD') AS INT) 
            ORDER BY CAST(to_char(event_date, 'YYYYMMDD') AS INT)
        ) AS active_dates_int
    FROM event_devices
    GROUP BY user_id, device_id, browser_type
)
SELECT 
    user_id,
    jsonb_object_agg(COALESCE(browser_type, 'unknown'), to_jsonb(active_dates)) AS device_activity_datelist,
    jsonb_object_agg(COALESCE(browser_type, 'unknown'), to_jsonb(active_dates_int)) AS device_activity_datelist_int,
    CURRENT_TIMESTAMP  AS snap_dt
FROM agg_browser
GROUP BY user_id;
--select * from user_devices_cumulated;


--- A DDL for `hosts_cumulated` table 
-- a `host_activity_datelist` which logs to see which dates each host is experiencing any activity
--- The incremental query to generate `host_activity_datelist`
DROP TABLE IF EXISTS hosts_cumulated;
create table hosts_cumulated (
    host TEXT,
    host_activity_datelist JSONB,
    snap_dt TIMESTAMP,
    data_date date,
    primary key (host,data_date)
);


--generation query
--select min(event_time), max(event_time) from events e -2023-01-01 & 2023-01-31
with yesterday as
(
select  coalesce(host,'unknown') as host,
        coalesce(host_activity_datelist, null) as host_activity_datelist,
        coalesce(data_date,'2023-01-01') as data_date,
        coalesce(snap_dt,null) as snap_dt
from hosts_cumulated e
where cast(data_date as date) = '2023-01-01'
),
today as 
(
select  COALESCE(e.host, 'unknown') AS host,
        CAST(e.event_time AS DATE) AS event_date,
        '2023-01-02' as data_date,
        CURRENT_TIMESTAMP  AS snap_dt
from events e
where cast(event_time as date) = '2023-01-02'
)

/*
INSERT INTO hosts_cumulated
WITH host_events AS (
    SELECT 
        COALESCE(e.host, 'unknown') AS host,
        CAST(e.event_time AS DATE) AS event_date
    FROM events e
),
agg_hosts AS (
    SELECT 
        host,
        ARRAY_AGG(DISTINCT event_date ORDER BY event_date) AS active_dates
    FROM host_events
    GROUP BY host
)
SELECT 
    host,
    to_jsonb(active_dates) AS host_activity_datelist,
    CURRENT_TIMESTAMP AS snap_dt
FROM agg_hosts; */


/*
- A monthly, reduced fact table DDL `host_activity_reduced`
   - month
   - host
   - hit_array - think COUNT(1)
   - unique_visitors array -  think COUNT(DISTINCT user_id) 
*/


--- An incremental query that loads `host_activity_reduced` - day-by-day