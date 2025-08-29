
with deduped as (
	select g.game_date_est,gd.*, row_number() over (partition by gd.game_id, team_id, player_id order by g.game_date_est) as row_num
	from game_details gd
	join games g on gd.game_id = g.game_id
)
select * from deduped where row_num=1

