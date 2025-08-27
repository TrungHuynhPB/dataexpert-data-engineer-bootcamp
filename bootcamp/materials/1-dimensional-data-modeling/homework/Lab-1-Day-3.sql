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


--2.4 view the vertices type
select type, count(1) from vertices group by 1;

--2.5 
insert into edges
with deduped as 
(
select *, row_number() over (partition by player_id, game_id) as rn
from game_details
)
select player_id as subject_identifier,
	'player'::vertex_type as subject_type,
	game_id as object_identifier,
	'game'::vertex_type as object_type,
	'plays_in'::edge_type as edge_type,
	json_build_object(
		'start_position', start_position,
		'pts', pts,
		'team_id', team_id,
		'team_abbreviation', team_abbreviation
	)  as properties
from deduped where rn=1;

select * from vertices;
select * from edges;


--2.6 view top players with highest points
select v.properties->>'player_name',
	MAX(cast(e.properties->>'pts' as integer)) 
from vertices v join edges e 
on e.subject_identifier = v.identifier
and e.subject_type = v.type 
group by 1 order by 2 desc;


-- 2.7 Another way: Create both type of edges with 1 single query
insert into edges
with deduped as 
(select *, row_number() over (partition by player_id, game_id) as rn
from game_details),
filtered as
(select *  from deduped where rn=1),
aggregated as
(
select f1.player_id as subject_player_id, MAX(f1.player_name) as subject_player_name,
	f2.player_id as object_player_id, MAX(f2.player_name) as object_player_name,
	case when f1.team_abbreviation = f2.team_abbreviation then 'shares_team'::edge_type else 'plays_against'::edge_type
	end as edge_type,
	count(1) as num_games,
	SUM(f1.pts) as subject_points,
	SUM(f2.pts) as object_points
from filtered f1 join filtered f2
on f1.game_id = f2.game_id 
and f1.player_name <> f2.player_name
where f1.player_id > f2.player_id
group by f1.player_id, f2.player_id, case when f1.team_abbreviation = f2.team_abbreviation then 'shares_team'::edge_type else 'plays_against'::edge_type
	end
)
select subject_player_id as subject_identifier,
	 'player'::vertex_type as subject_type,
	 object_player_id as object_identifier,
	 'player'::vertex_type as object_type,
	 edge_type as edge_type,
	 json_build_object(
	 	'num_games', num_games,
	 	'subject_points', subject_points,
	 	'object points', object_points
	 )
from aggregated

-- 2.8
select v.properties->>'player_name',
	   e.object_identifier,
	   cast(v.properties->>'number_of_games' as real)/
	   case when cast(v.properties->>'total_points' as real) = 0 then 1 else cast(v.properties->>'total_points' as real) end,
	   e.properties->>'subject_points',
	   e.properties->>'num_games'
from vertices v join edges e on v.identifier=e.subject_identifier and v.type=e.subject_type 
where e.object_type = 'player'::vertex_type;
