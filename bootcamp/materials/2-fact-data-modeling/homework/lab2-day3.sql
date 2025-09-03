create table array_metrics (
	user_id numeric,
	month_start DATE,
	metric_name TEXT,
	metric_array real[],
	primary key (user_id, month_start, metric_name)
);

with daily_aggregate as (
	select user_id, count(1) as num_site_hits
	from events 
	where date(:event_time) = date(:'2023-01-01')
	and user_id is not null
	group by user_id
),
yesterday_array as 
(
select * from array_metrics
where month_start = DATE(:'2023-01-01')
)
select coalesce(da.user_id, ya.user_id) as user_id,
	coalesce(ya.month_start, date_trunc('month',da.date)) as month_start
	'site_hits' as metric_name,
	
from daily_aggregate da full outer join yesterday_array ya on da.user_i = ya.user_id