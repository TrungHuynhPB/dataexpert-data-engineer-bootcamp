create table array_metrics (
	user_id numeric,
	month_start DATE,
	metric_name TEXT,
	metric_array real[],
	primary key (user_id, month_start, metric_name)
);a