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
select game_id as identifier,
	'game'::vertex_type as type,
	json_build_object(
	'pts_home', pts_home,
	'pts_away', pts_away,
	'winning_team', case when home_team_wins=1 then home_team_id else visitor_team_id end
	) as properties
from games;






