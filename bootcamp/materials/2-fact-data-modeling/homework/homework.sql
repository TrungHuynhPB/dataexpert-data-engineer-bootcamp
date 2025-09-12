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
FROM agg_hosts;

--generation query
--select min(event_time), max(event_time) from events e -2023-01-01 & 2023-01-31
-- incremental query
WITH yesterday AS (
    SELECT  
        COALESCE(host,'unknown') AS host,
        host_activity_datelist,
        data_date,
        snap_dt
    FROM hosts_cumulated e
    WHERE CAST(data_date AS date) = '2023-01-06'
),
today AS (
    SELECT  
        COALESCE(e.host, 'unknown') AS host,
        CAST(e.event_time AS DATE) AS event_date,
        '2023-01-07'::date AS data_date,
        CURRENT_TIMESTAMP AS snap_dt
    FROM events e
    WHERE CAST(e.event_time AS date) = '2023-01-07'
),
agg_today AS (
    SELECT 
        host,
        ARRAY_AGG(DISTINCT event_date ORDER BY event_date) AS today_dates,
        data_date,
        CURRENT_TIMESTAMP AS snap_dt
    FROM today
    GROUP BY host, data_date
),
merged AS (
    SELECT 
        COALESCE(y.host, t.host) AS host,
        -- Merge yesterday's datelist (if any) with today's
        to_jsonb(
            ARRAY(
                SELECT DISTINCT d::date
                FROM (
                    SELECT unnest(COALESCE(ARRAY(
                        SELECT x::date
                        FROM jsonb_array_elements_text(y.host_activity_datelist) AS x
                    ), '{}')) AS d
                    UNION ALL
                    SELECT unnest(COALESCE(t.today_dates, '{}')) AS d
                ) all_dates
                ORDER BY d
            )
        ) AS host_activity_datelist,
        t.data_date,
        t.snap_dt
    FROM agg_today t
    FULL OUTER JOIN yesterday y
        ON y.host = t.host
)
INSERT INTO hosts_cumulated (host, host_activity_datelist, data_date, snap_dt)
SELECT * FROM merged;

-- select * from hosts_cumulated;



/*
- A monthly, reduced fact table DDL `host_activity_reduced`
   - month
   - host
   - hit_array - think COUNT(1)
   - unique_visitors array -  think COUNT(DISTINCT user_id) 
*/
DROP TABLE IF EXISTS host_activity_reduced;
CREATE TABLE host_activity_reduced (
    data_date DATE,
    host TEXT,
    hit_array INT[],
    unique_visitors_array INT[],
    snap_dt TIMESTAMP,
    PRIMARY KEY (data_date, host)
);

INSERT INTO host_activity_reduced (data_date, host, hit_array, unique_visitors_array, snap_dt)
WITH base AS (
    SELECT 
        cast(event_time as date) AS data_date,
        CAST(event_time AS DATE) AS event_date,
        COALESCE(host, 'unknown') AS host,
        user_id
    FROM events
),
daily_agg AS (
    SELECT 
        data_date,
        host,
        event_date,
        COUNT(1) AS hits,
        COUNT(DISTINCT user_id) AS unique_visitors
    FROM base
    GROUP BY data_date, host, event_date
),
month_agg AS (
    SELECT
        data_date,
        host,
        ARRAY_AGG(hits ORDER BY event_date) AS hit_array,
        ARRAY_AGG(unique_visitors ORDER BY event_date) AS unique_visitors_array
    FROM daily_agg
    GROUP BY data_date, host
)
SELECT 
    data_date,
    host,
    hit_array,
    unique_visitors_array,
    CURRENT_TIMESTAMP AS snap_dt
FROM month_agg;




--- An incremental query that loads `host_activity_reduced` - day-by-day
WITH daily_stats AS (
    SELECT 
        cast( e.event_time as date) AS data_date,
        COALESCE(e.host, 'unknown') AS host,
        CAST(e.event_time AS DATE) AS event_date,
        COUNT(1) AS hits,
        COUNT(DISTINCT e.user_id) AS unique_visitors
    FROM events e
    WHERE CAST(e.event_time AS DATE) = CURRENT_DATE - INTERVAL '1 day'  -- 👈 load "yesterday"
    GROUP BY 1, 2, 3
),
upserted AS (
    SELECT 
        d.data_date,
        d.host,
        ARRAY[d.hits] AS hit_array,
        ARRAY[d.unique_visitors] AS unique_visitors_array,
        CURRENT_TIMESTAMP AS snap_dt
    FROM daily_stats d
)
INSERT INTO host_activity_reduced (data_date, host, hit_array, unique_visitors_array, snap_dt)
SELECT data_date, host, hit_array, unique_visitors_array, snap_dt
FROM upserted
ON CONFLICT (data_date, host) DO UPDATE
SET hit_array = host_activity_reduced.hit_array || EXCLUDED.hit_array,
    unique_visitors_array = host_activity_reduced.unique_visitors_array || EXCLUDED.unique_visitors_array,
    snap_dt = EXCLUDED.snap_dt;

-- select * from host_activity_reduced

