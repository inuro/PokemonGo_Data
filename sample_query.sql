select
row_number() OVER (ORDER BY Q.true_dps desc) AS rank,
*
from(
select
  ME.id
, LOCALIZE_ME.jp as name
--, LOCALIZE_ME_TYPE1.jp as type1
--, LOCALIZE_ME_TYPE2.jp as type2
, LOCALIZE_ME_FASTMOVE.jp as fastmove
--, LOCALIZE_TYPE_ME_FASTMOVE.jp as fm_type
, LOCALIZE_ME_CHARGEMOVE.jp as chargemove
--, LOCALIZE_TYPE_ME_CHARGEMOVE.jp as cm_type
/*
, ME.at
, ME.df
, ME.st
, Round(ME_FASTMOVE.firepower::numeric, 0) as fm_dmg
, Round(ME_FASTMOVE.duration::numeric / 1000, 2) as fm_dur
, ME_FASTMOVE.energy_gain as fm_gain
, Round((ME_FASTMOVE.firepower / ME_FASTMOVE.duration)::numeric * 1000, 1) as fm_dps
, Round((ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration * 1000)::numeric, 2) as fm_gps

, Round(ME_CHARGEMOVE.firepower::numeric,0) as cm_dmg
, ME_CHARGEMOVE.energy_cost as cm_cost
, Round(ME_CHARGEMOVE.duration::numeric / 1000, 2) as cm_dur
, Round((ME_CHARGEMOVE.energy_cost::numeric / (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration) / 1000)::numeric, 2) as chargetime

, Round(((ME_CHARGEMOVE.energy_cost::numeric / (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration) + ME_CHARGEMOVE.duration) / 1000)::numeric, 2) as dur_1cycle
, Round((((ME_FASTMOVE.firepower / ME_FASTMOVE.duration) * ME_CHARGEMOVE.energy_cost::numeric / (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration) +  ME_CHARGEMOVE.firepower))::numeric, 2) as dmg_1cycle
*/
, Round(
  (
    (
      (ME_FASTMOVE.firepower / ME_FASTMOVE.duration) *
      ME_CHARGEMOVE.energy_cost::numeric /
      (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration)
      +  ME_CHARGEMOVE.firepower
    ) /
    (
      ME_CHARGEMOVE.energy_cost::numeric /
      (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration)
      + ME_CHARGEMOVE.duration
    ) * 1000
  )::numeric, 2
) as true_dps

, case when (ME_FASTMOVE.version & ME_CHARGEMOVE.version & B'100')::int > 0 then null else 'Legacy' end as legacy

-- , LOCALIZE_YOU.jp as target
-- , YOU.at as target_at
-- , YOU.df as target_df
-- , YOU.st as target_st

-- challenger pokemon
from pokemon.pokemon ME
join pokemon.view_firepower_fastmove ME_FASTMOVE on ME_FASTMOVE.pokemon_id = ME.id
join pokemon.view_firepower_chargemove ME_CHARGEMOVE on ME_CHARGEMOVE.pokemon_id = ME.id
left join pokemon.type ME_TYPE1 on ME_TYPE1.id=ME.type1
left join pokemon.type ME_TYPE2 on ME_TYPE2.id=ME.type2
-- localize for challenger pokemon
join pokemon.localize_pokemon LOCALIZE_ME on LOCALIZE_ME.id=ME.id
left join pokemon.localize_type LOCALIZE_ME_TYPE1 on LOCALIZE_ME_TYPE1.id=ME.type1
left join pokemon.localize_type LOCALIZE_ME_TYPE2 on LOCALIZE_ME_TYPE2.id=ME.type2
join pokemon.localize_fastmove LOCALIZE_ME_FASTMOVE on LOCALIZE_ME_FASTMOVE.id=ME_FASTMOVE.move_id
join pokemon.localize_chargemove LOCALIZE_ME_CHARGEMOVE on LOCALIZE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_id
join pokemon.localize_type LOCALIZE_TYPE_ME_FASTMOVE on LOCALIZE_TYPE_ME_FASTMOVE.id=ME_FASTMOVE.move_type
join pokemon.localize_type LOCALIZE_TYPE_ME_CHARGEMOVE on LOCALIZE_TYPE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_type

-- target pokemon
--join pokemon.localize_pokemon LOCALIZE_YOU on true
--join pokemon.pokemon YOU on YOU.id=LOCALIZE_YOU.id

-- constants
-- AND LOCALIZE_YOU.jp='ハピナス'

AND ME_FASTMOVE.firepower is not null
AND ME.id <> ALL (ARRAY[151,150,146,145,144,132,243,244,245,249,250,251])
--AND LOCALIZE_ME.jp='カイリュー'
AND (ME_FASTMOVE.version & ME_CHARGEMOVE.version)::int > 0
--AND LOCALIZE_TYPE_ME_CHARGEMOVE.jp='でんき'
) Q
order by Q.true_dps desc limit 100;
