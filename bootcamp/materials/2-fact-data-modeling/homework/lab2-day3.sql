create table array_metrics (
	user_id numeric,
	month_start DATE,
	metric_name TEXT,
	metric_array real[],
	primary key (user_id, month_start, metric_name)
);
delete from array_metrics;

insert into array_metrics
with daily_aggregate as (
	select user_id, date(event_time) as date, count(1) as num_site_hits
	from events 
	where date(event_time) = date('2023-01-04')
	and user_id is not null
	group by user_id, date(event_time)
),
yesterday_array as 
(
select * from array_metrics
where month_start = DATE('2023-01-01')
)
select coalesce(da.user_id, ya.user_id) as user_id,
	coalesce(ya.month_start, date_trunc('month',da.date)) as month_start,
	'site_hits' as metric_name,
	case when ya.metric_array is not null then ya.metric_array || array[coalesce(da.num_site_hits,0)]
	when  ya.metric_array is null then array_fill(0, array[coalesce(date - date(date_trunc('month',date)),0)]) || array[coalesce(da.num_site_hits,0)] end as metric_array
from daily_aggregate da full outer join yesterday_array ya on da.user_id = ya.user_id
on conflict (user_id, month_start, metric_name)
do 
 update set metric_array = EXCLUDED.metric_array;

--
with aggs as 
( 
select metric_name, month_start, array[sum(metric_array[1]),sum(metric_array[2]),sum(metric_array[3]),sum(metric_array[4])] as summed_array
from array_metrics
group by metric_name, month_start)
select metric_name, month_start + cast(cast(index -1 as text) || 'day' as interval) as date, elem as value
from aggs cross join unnest(aggs.summed_array)
with ordinality as a(elem,index)

-- array_metrics
select cardinality(metric_array), count(1)
from array_metrics
group by 1