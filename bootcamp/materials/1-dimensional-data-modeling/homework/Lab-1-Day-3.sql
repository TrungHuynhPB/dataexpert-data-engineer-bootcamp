--1. Create types and tables
drop type if exists vertex_type cascade;
drop table if exists vertices;
create type vertex_type as ENUM('player', 'team', 'game');

create table  vertices (
	identifier TEXT,
	type vertex_type,
	properties JSON,
	primary key (identifier, type)
)

drop type if exists edge_type cascade;
create type edge_type as 
 enum('plays_against',
 	 'shares_team',
 	 'plays_in',
 	 'plays_on')

drop table if exists edges;
create table edges (
	subject_identifier TEXT,
	subject_type vertex_type,
	object_identifier TEXT,
	object_type vertex_type,
	edge_type edge_type,
	properties JSON,
	primary key (subject_identifier,
				 subject_type,
				 object_identifier,
				 object_type,
				 edge_type)
)

-- 2. view the data source table
select * from games;

	-- 2.1 insert into vertices table - to get team points- winning team
insert into vertices
select game_id as identifier,
	'game'::vertex_type as type,
	json_build_object(
	'pts_home', pts_home,
	'pts_away', pts_away,
	'winning_team', case when home_team_wins=1 then home_team_id else visitor_team_id end
	) as properties --this can be used as edges to create our first verticie
from games;

	-- 2.2 to get player's stats, min and max stats
insert into vertices
with players_agg as 
(
select player_id as identifier, 
	MAX(player_name) as player_name, --we just want name of player, using max or min is fine
	count(1) as number_of_games,
	sum(pts) as total_points, 
	array_agg(distinct team_id) as teams
from game_details
group by player_id
)
select identifier, 'player'::vertex_type,
json_build_object('player_name', player_name, 'number_of_games', number_of_games, 'total_points', total_points,
'teams', teams)
from players_agg 

	--2.3 get team stats
insert into vertices
with teams_deduped as (
	select *, row_number() over (partition by team_id) as rn
	from teams
)
select team_id as identifier,
'team'::vertex_type as type,
json_build_object('abbreviation', abbreviation, 'nickname', nickname, 'city', city, 'arena', arena, 'year_founded', yearfounded)
from teams_deduped where rn=1;


--2.4 
select type, count(1) from vertices group by 1;


