#!/bin/bash

# search strongest pokemon against target pokemon
# [usage]
# $ pokemon_ranking.sh [-l limit] [-t target_pokemon_name_jp] [-c challenger_pokemon_name_jp]
# $ ./ pokemon_ranking.sh -l 40 -t カイリュー -c シャワーズ

# please modify psql command for your environment
PSQL_COMMAND='psql postgres'

usage_exit() {
        echo "Usage: $0 [-l limit] [-t target_pokemon_name_jp] [-c challenger_pokemon_name_jp]" 1>&2
        exit 1
}
while getopts t:c:l: OPT
do
    case $OPT in
        t)  TARGET=$OPTARG
            ;;
        c)  CHALLENGER=$OPTARG
            ;;
        l)  LIMIT=$OPTARG
            ;;
        \?) usage_exit
            ;;
    esac
done
shift $((OPTIND - 1))

if [ ! $TARGET ]; then
  TARGET='カビゴン'
fi
if [ ! $LIMIT ]; then
  LIMIT=40
fi
if [ $CHALLENGER ]; then
  CHALLENGER_COMMENT_OUT=''
else
  CHALLENGER_COMMENT_OUT='--'
fi



echo "target: $TARGET"
echo "challenger: $CHALLENGER"
echo "limit: $LIMIT"


SQL=$(cat << _EOS_
select
  Q2.rank
, ROUND((Q2.true_dps - T2.AVRG) / T2.STDRD * 10 + 50, 1) as T
--, Q2.id
, Q2.name
, Q2.type1
, Q2.type2
, Q2.at
, Q2.df
, Q2.st

, Q2.fastmove
, case Q2.MP_FAST
  when 1.0 then null
  when 1.25 then '+'
  when 1.5625 then '++'
  when 0.8 then '-'
  when 0.64 then '--'
  end as EF
, Q2.fm_pw as dmg
, Q2.fm_dur as dur
, Q2.fm_gain as chg

, Q2.chargemove
, case Q2.MP_CHARGE
  when 1.0 then null
  when 1.25 then '+'
  when 1.5625 then '++'
  when 0.8 then '-'
  when 0.64 then '--'
  end as EF
, Q2.cm_pw as dmg
, Q2.cm_dur as dur
, Q2.cm_cost as cst

, Q2.true_dps
, Q2.legacy
--, Q2.target
from(
  select
  row_number() OVER (ORDER BY Q1.true_dps desc) AS rank
, *
from(
select
  ME.id as id
, LOCALIZE_ME.jp as name
, LOCALIZE_ME_TYPE1.jp as type1
, LOCALIZE_ME_TYPE2.jp as type2
, LOCALIZE_ME_FASTMOVE.jp as fastmove
--, LOCALIZE_TYPE_ME_FASTMOVE.jp as fm_type
, LOCALIZE_ME_CHARGEMOVE.jp as chargemove
--, LOCALIZE_TYPE_ME_CHARGEMOVE.jp as cm_type
, ME.at
, ME.df
, ME.st

, ME_FASTMOVE.power as fm_pw
, Round(ME_FASTMOVE.firepower::numeric, 0) as fm_dmg
, Round(ME_FASTMOVE.duration::numeric / 1000, 1) as fm_dur
, ME_FASTMOVE.energy_gain as fm_gain
, Round((ME_FASTMOVE.firepower / ME_FASTMOVE.duration)::numeric * 1000, 1) as fm_dps
, Round((ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration * 1000)::numeric, 2) as fm_gps

, ME_CHARGEMOVE.power as cm_pw
, Round(ME_CHARGEMOVE.firepower::numeric,0) as cm_dmg
, ME_CHARGEMOVE.energy_cost as cm_cost
, Round(ME_CHARGEMOVE.duration::numeric / 1000, 2) as cm_dur
, Round((ME_CHARGEMOVE.energy_cost::numeric / (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration) / 1000)::numeric, 2) as chargetime

, Round(((ME_CHARGEMOVE.energy_cost::numeric / (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration) + ME_CHARGEMOVE.duration) / 1000)::numeric, 2) as dur_1cycle
, Round((((ME_FASTMOVE.firepower / ME_FASTMOVE.duration) * ME_CHARGEMOVE.energy_cost::numeric / (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration) +  ME_CHARGEMOVE.firepower))::numeric, 2) as dmg_1cycle


, (FAST_MP_1.multiplier * (case when YOU.type2 is null then 1 else FAST_MP_2.multiplier end))  as MP_FAST
, (CHARGE_MP_1.multiplier * (case when YOU.type2 is null then 1 else CHARGE_MP_2.multiplier end))  as MP_CHARGE

, Round(
  (
    (
      (ME_FASTMOVE.firepower * (FAST_MP_1.multiplier * (case when YOU.type2 is null then 1 else FAST_MP_2.multiplier end)) / ME_FASTMOVE.duration) *
      ME_CHARGEMOVE.energy_cost::numeric /
      (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration)
      +  ME_CHARGEMOVE.firepower * (CHARGE_MP_1.multiplier * (case when YOU.type2 is null then 1 else CHARGE_MP_2.multiplier end))
    ) /
    (
      ME_CHARGEMOVE.energy_cost::numeric /
      (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration)
      + ME_CHARGEMOVE.duration
    ) * 1000
  )::numeric, 0
) as true_dps
, case when (ME_FASTMOVE.version & ME_CHARGEMOVE.version & B'100')::int > 0 then null else 'Legacy' end as legacy
, LOCALIZE_YOU.jp as target
/*
, YOU_TYPE1.codename as type1
, YOU_TYPE2.codename as type2
*/
/*
, YOU.at as target_at
, YOU.df as target_df
, YOU.st as target_st
*/

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

left join pokemon.localize_fastmove LOCALIZE_ME_FASTMOVE on LOCALIZE_ME_FASTMOVE.id=ME_FASTMOVE.move_id
left join pokemon.localize_chargemove LOCALIZE_ME_CHARGEMOVE on LOCALIZE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_id
left join pokemon.localize_type LOCALIZE_TYPE_ME_FASTMOVE on LOCALIZE_TYPE_ME_FASTMOVE.id=ME_FASTMOVE.move_type
left join pokemon.localize_type LOCALIZE_TYPE_ME_CHARGEMOVE on LOCALIZE_TYPE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_type

-- target pokemon
join pokemon.localize_pokemon LOCALIZE_YOU on true
join pokemon.pokemon YOU on YOU.id=LOCALIZE_YOU.id
left join pokemon.type YOU_TYPE1 on YOU_TYPE1.id=YOU.type1
left join pokemon.type YOU_TYPE2 on YOU_TYPE2.id=YOU.type2

join pokemon.multiplier FAST_MP_1 on FAST_MP_1.type_id_offense=ME_FASTMOVE.move_type and FAST_MP_1.type_id_defense=YOU.type1
left join pokemon.multiplier FAST_MP_2 on FAST_MP_2.type_id_offense=ME_FASTMOVE.move_type and FAST_MP_2.type_id_defense=YOU.type2
join pokemon.multiplier CHARGE_MP_1 on CHARGE_MP_1.type_id_offense=ME_CHARGEMOVE.move_type and CHARGE_MP_1.type_id_defense=YOU.type1
left join pokemon.multiplier CHARGE_MP_2 on CHARGE_MP_2.type_id_offense=ME_CHARGEMOVE.move_type and CHARGE_MP_2.type_id_defense=YOU.type2

-- conditions
WHERE true
AND (ME_FASTMOVE.version & ME_CHARGEMOVE.version)::int > 0
AND ME_FASTMOVE.firepower is not null
AND ME.id <> ALL (ARRAY[151,150,146,145,144,132,243,244,245,249,250,251])

AND LOCALIZE_YOU.jp='$TARGET'
--AND LOCALIZE_TYPE_ME_CHARGEMOVE.jp='でんき'
) Q1
) Q2
join(
  select
    avg(T1.true_dps) as AVRG
  , stddev(T1.true_dps) as STDRD
  from(
  select
    ME.id
  , ME.codename as name
  , ME_FASTMOVE.move_id as fastmove
  , ME_CHARGEMOVE.move_id as chargemove
  , Round(
    (
      (
        (ME_FASTMOVE.firepower * (FAST_MP_1.multiplier * (case when YOU.type2 is null then 1 else FAST_MP_2.multiplier end)) / ME_FASTMOVE.duration) *
        ME_CHARGEMOVE.energy_cost::numeric /
        (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration)
        +  ME_CHARGEMOVE.firepower * (CHARGE_MP_1.multiplier * (case when YOU.type2 is null then 1 else CHARGE_MP_2.multiplier end))
      ) /
      (
        ME_CHARGEMOVE.energy_cost::numeric /
        (ME_FASTMOVE.energy_gain::numeric / ME_FASTMOVE.duration)
        + ME_CHARGEMOVE.duration
      ) * 1000
    )::numeric, 0
  ) as true_dps

  -- challenger pokemon
  from pokemon.pokemon ME
  join pokemon.localize_pokemon LOCALIZE_ME on LOCALIZE_ME.id=ME.id
  join pokemon.view_firepower_fastmove ME_FASTMOVE on ME_FASTMOVE.pokemon_id = ME.id
  join pokemon.view_firepower_chargemove ME_CHARGEMOVE on ME_CHARGEMOVE.pokemon_id = ME.id

  -- target pokemon
  join pokemon.localize_pokemon LOCALIZE_YOU on true
  join pokemon.pokemon YOU on YOU.id=LOCALIZE_YOU.id
  left join pokemon.type YOU_TYPE1 on YOU_TYPE1.id=YOU.type1
  left join pokemon.type YOU_TYPE2 on YOU_TYPE2.id=YOU.type2

  join pokemon.multiplier FAST_MP_1 on FAST_MP_1.type_id_offense=ME_FASTMOVE.move_type and FAST_MP_1.type_id_defense=YOU.type1
  left join pokemon.multiplier FAST_MP_2 on FAST_MP_2.type_id_offense=ME_FASTMOVE.move_type and FAST_MP_2.type_id_defense=YOU.type2
  join pokemon.multiplier CHARGE_MP_1 on CHARGE_MP_1.type_id_offense=ME_CHARGEMOVE.move_type and CHARGE_MP_1.type_id_defense=YOU.type1
  left join pokemon.multiplier CHARGE_MP_2 on CHARGE_MP_2.type_id_offense=ME_CHARGEMOVE.move_type and CHARGE_MP_2.type_id_defense=YOU.type2

  -- conditions
  WHERE true
  AND (ME_FASTMOVE.version & ME_CHARGEMOVE.version)::int > 0
  AND ME_FASTMOVE.firepower is not null
  AND ME.id <> ALL (ARRAY[151,150,146,145,144,132,243,244,245,249,250,251])

  AND LOCALIZE_YOU.jp='$TARGET'
  --AND LOCALIZE_TYPE_ME_CHARGEMOVE.jp='でんき'
  ) T1
) T2 on true
${CHALLENGER_COMMENT_OUT} WHERE Q2.name='$CHALLENGER'
order by Q2.true_dps desc
limit $LIMIT
;

_EOS_
)

echo "${SQL}" | $PSQL_COMMAND
exit 0
