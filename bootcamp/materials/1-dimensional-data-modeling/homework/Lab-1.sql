/************************************/
/************************************/
/**********Lab 1 ************/
/************************************/
/************************************/
--View Player Seasons table
select * from player_seasons;

-- Create Type
drop table if exists players;
drop type if exists season_stats;
create type season_stats as (season integer, gp integer, pts real, reb real, ast real);
drop type if exists scoring_class;
create type scoring_class as enum('star','good','average','bad');

-- Create Players table
create table players (
	player_name TEXT,
	height TEXT,
	college TEXT,
	country TEXT,
	draft_year TEXT,
	draft_round TEXT,
	draft_number TEXT,
	season_stats season_stats[],
	scoring_class scoring_class,
	years_since_last_season INTEGER,
	is_active BOOLEAN,
	current_season INTEGER,
	PRIMARY KEY(player_name, current_season)
);

-- Min/Max of player_seasons 
select min(season) from player_seasons; --1996
select max(season) from player_seasons; --2022
select distinct season from player_seasons order by season asc ;
-- Insert table script for each year
insert into players
with yesterday as 
	(select * from players where current_season= 2000)
, today as 
	(select * from player_seasons where season= 2001)
select COALESCE(ls.player_name, ts.player_name) as player_name,
        COALESCE(ls.height, ts.height) as height,
        COALESCE(ls.college, ts.college) as college,
        COALESCE(ls.country, ts.country) as country,
        COALESCE(ls.draft_year, ts.draft_year) as draft_year,
        COALESCE(ls.draft_round, ts.draft_round) as draft_round,
        COALESCE(ls.draft_number, ts.draft_number) as draft_number,
        case when ls.season_stats is null then ARRAY[row(ts.season,ts.gp,ts.pts,ts.reb,ts.ast)::season_stats]
        	when ts.season is not null then ls.season_stats || ARRAY[row(ts.season,ts.gp,ts.pts,ts.reb,ts.ast)::season_stats]
        else ls.season_stats
        	end as season_stats,
         CASE
             WHEN ts.season IS NOT NULL THEN
                 (CASE WHEN ts.pts > 20 THEN 'star'
                    WHEN ts.pts > 15 THEN 'good'
                    WHEN ts.pts > 10 THEN 'average'
                    ELSE 'bad' END)::scoring_class
             ELSE ls.scoring_class end as scoring_class,
             case
         	when ts.season is not null then 0
         else ls.years_since_last_season + 1
         end as years_since_last_season,
         ts.season IS NOT NULL as is_active,
       	coalesce(ts.season, ls.current_season + 1) as current_season
from today ts full outer join yesterday ls on ts.player_name = ls.player_name;

--Query to test results

   --First season points vs Latest season points
select player_name, (season_stats[1]::season_stats).pts as first_season_pts ,
	(season_stats[cardinality(season_stats)]::season_stats).pts as latest_season_pts 
from players 
where current_season = 2001 

  --Performance query = Latest season pts / first season pts
select player_name, (season_stats[cardinality(season_stats)]::season_stats).pts/ 
	case when (season_stats[1]::season_stats).pts = 0 then 1 else (season_stats[1]::season_stats).pts end as performance
from players 
where current_season = 2001 
order by 2 desc

