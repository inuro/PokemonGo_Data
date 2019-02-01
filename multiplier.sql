With MP as (select
  type_id_defense as id
,  max(case when type_id_offense='1' then multiplier else null end) as Normal
,  max(case when type_id_offense='2' then multiplier else null end) as Fighting
,  max(case when type_id_offense='3' then multiplier else null end) as Flying
,  max(case when type_id_offense='4' then multiplier else null end) as Poison
,  max(case when type_id_offense='5' then multiplier else null end) as Ground
,  max(case when type_id_offense='6' then multiplier else null end) as Rock
,  max(case when type_id_offense='7' then multiplier else null end) as Bug
,  max(case when type_id_offense='8' then multiplier else null end) as Ghost
,  max(case when type_id_offense='9' then multiplier else null end) as Steel
,  max(case when type_id_offense='10' then multiplier else null end) as Fire
,  max(case when type_id_offense='11' then multiplier else null end) as Water
,  max(case when type_id_offense='12' then multiplier else null end) as Grass
,  max(case when type_id_offense='13' then multiplier else null end) as Electric
,  max(case when type_id_offense='14' then multiplier else null end) as Phychic
,  max(case when type_id_offense='15' then multiplier else null end) as Ice
,  max(case when type_id_offense='16' then multiplier else null end) as Dragon
,  max(case when type_id_offense='17' then multiplier else null end) as Dark
,  max(case when type_id_offense='18' then multiplier else null end) as Fairy
from pokemon.multiplier
group by type_id_defense)
select
  L.en,
  MP.*
from MP
join pokemon.localize_type L on L.id=MP.id
order by MP.id
;
