--Dimensional Data Modeling - Day 2 Lab - Building Slowly Changing Dimensions

drop table if exists players_scd;
create table players_scd (
	player_name TEXT,
	scoring_class scoring_class,
	is_active BOOLEAN,
	start_season INTEGER,
	end_season INTEGER,
	current_season INTEGER,
	primary key (player_name, start_season)
);

/* Manual Way 1: to insert data for slowly changing dimension table */
-- Cons: using many Windows function which increases memory and load on machine.
insert into players_scd
with with_previous as
(
select
player_name,
current_season,
scoring_class,
is_active,
LAG(scoring_class,1) over (partition by player_name order by current_season) as previous_scoring_class,
LAG(is_active,1) over (partition by player_name order by current_season) as previous_is_active
from players
where current_season <= 2021
),
with_indicators as
(
select *,
	case when scoring_class <> previous_scoring_class then 1 else 0 end as scoring_class_change_indicator,
	case when is_active <> previous_is_active then 1 else 0 end as is_active_change_indicator,
   case when scoring_class <> previous_scoring_class then 1
	    when is_active <> previous_is_active then 1 else 0 end as change_indicator --combine 2 indicators into 1 column
from with_previous
),
with_streaks as
(
select *, sum(change_indicator) over (partition by player_name order by current_season) as streak_identifier
from with_indicators
)
select player_name,/* streak_identifier,*/ scoring_class, is_active,  MIN(current_season) as start_season,  MAX(current_season) as end_season,
2021 as current_season
from with_streaks
group by player_name, streak_identifier, is_active, scoring_class 
order by player_name, streak_identifier

--Query result
select * from players_scd;


WITH streak_started AS (
    SELECT player_name,
           current_season,
           scoring_class,
           LAG(scoring_class, 1) OVER
               (PARTITION BY player_name ORDER BY current_season) <> scoring_class
               OR LAG(scoring_class, 1) OVER
               (PARTITION BY player_name ORDER BY current_season) IS NULL
               AS did_change
    FROM players
),
     streak_identified AS (
         SELECT
            player_name,
                scoring_class,
                current_season,
            SUM(CASE WHEN did_change THEN 1 ELSE 0 END)
                OVER (PARTITION BY player_name ORDER BY current_season) as streak_identifier
         FROM streak_started
     ),
     aggregated AS (
         SELECT
            player_name,
            scoring_class,
            streak_identifier,
            MIN(current_season) AS start_date,
            MAX(current_season) AS end_date
         FROM streak_identified
         GROUP BY 1,2,3
     )

     SELECT player_name, scoring_class, start_date, end_date
     FROM aggregated

/* Manual Way 2:  */
drop type if exists scd_type;
create type scd_type as (scoring_class scoring_class, is_active boolean, start_season INTEGER, end_season INTEGER)
     
     
with last_season_scd as 
(
select * from players_scd
where current_season = 2021
and end_season = 2021
),
historical_scd as
(
select player_name, scoring_class, is_active, start_season, end_season
from players_scd
where current_season = 2021
and end_season < 2021
),
this_season_data as
(
select *
from players
where current_season = 2022
),
unchanged_records as
(
select ts.player_name,
ts.scoring_class, ts.is_active, -- condition matched for both ts vs ls
--ls.scoring_class, ls.is_active, -- condition matched for both ts vs ls
ls.start_season,
ts.current_season as end_season
from this_season_data ts join last_season_scd ls 
on ls.player_name = ts.player_name
where ts.scoring_class = ls.scoring_class
and ts.is_active = ls.is_active
),
changed_records as (
select ts.player_name,
--ts.scoring_class, ts.is_active, 
--ls.scoring_class, ls.is_active, 
--ls.start_season,
--ts.current_season as end_season,
unnest(ARRAY[
	ROW(ls.scoring_class,ls.is_active,ls.start_season,ls.end_season)::scd_type,
	ROW(ts.scoring_class,ts.is_active,ts.current_season,ts.current_season)::scd_type	
]) as records
from this_season_data ts join last_season_scd ls 
on ls.player_name = ts.player_name
where (ts.scoring_class <> ls.scoring_class
or ts.is_active <> ls.is_active
)
),
unested_changed_records as (
select player_name, (records::scd_type).scoring_class,
(records::scd_type).is_active,
(records::scd_type).start_season,
(records::scd_type).end_season
from changed_records
),
new_records as 
(
select ts.player_name,
ts.scoring_class,
ts.is_active,
ts.current_season as start_season,
ts.current_season as end_season
from this_season_data ts left join last_season_scd ls 
on ls.player_name = ts.player_name
where ls.player_name is null )
select * from historical_scd
union all
select * from unchanged_records
union all
select * from unested_changed_records
union all
select * from new_records 
