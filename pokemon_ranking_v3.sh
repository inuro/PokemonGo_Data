#!/bin/bash
# search strongest pokemon against target pokemon
# [usage]
# $ pokemon_ranking_v3.sh [-l limit] [-t target_pokemon_name_jp] [-f target_fastmove_jp][-c target_chargemove_jp] [-d chargemove_dodge]　[-s Sort]
# $ ./pokemon_ranking_v3.sh -l 100 -t バンギラス -f かみつく -c ストーンエッジ

# please modify psql command for your environment
PSQL_COMMAND='psql postgres'

usage_exit() {
        echo "Usage: $0 [-l limit] [-t target_pokemon_name_jp] [-c challenger_pokemon_name_jp]" 1>&2
        exit 1
}
while getopts m:t:f:c:l:d:s: OPT
do
    case $OPT in
        m)  ME=$OPTARG
            ;;
        t)  TARGET=$OPTARG
            ;;
        f)  TARGET_FASTMOVE=$OPTARG
            ;;
        c)  TARGET_CHARGEMOVE=$OPTARG
            ;;
        l)  LIMIT=$OPTARG
            ;;
        d)  DODGE=$OPTARG
            ;;
        s)  SORT=$OPTARG
            ;;
        \?) usage_exit
            ;;
    esac
done
shift $((OPTIND - 1))

MEONLY="AND me='${ME}'"
if [ ! $ME ]; then
  MEONLY=''
fi
if [ ! $TARGET ]; then
  TARGET='シャワーズ'
fi
if [ ! $TARGET_FASTMOVE ]; then
  TARGET_FASTMOVE='みずでっぽう'
fi
if [ ! $TARGET_CHARGEMOVE ]; then
  TARGET_CHARGEMOVE='ハイドロポンプ'
fi
if [ ! $LIMIT ]; then
  LIMIT=40
fi
if [ ! $DODGE]; then
  DODGE='false'
fi
if [ ! $SORT ]; then
  SORT='TotalDPS'
fi

echo "target: $TARGET"
echo "fastmove: $TARGET_FASTMOVE"
echo "chargemove: $TARGET_CHARGEMOVE"
echo "limit: $LIMIT"
echo "dodging chargemove?: $DODGE"
echo "sort by: $SORT"


SQL=$(cat << _EOS_
-- out end of nested queries ---------------------------------------------------
select
  row_number() OVER (ORDER BY TotalDPS desc) AS rank
, ROUND((TotalDPS - AVRG) / STDRD * 10 + 50, 1) as T
, me
, m_legacy as Legacy
, m_at as AT
, m_df as DF
, m_lv30hp as LV30HP

, m_fm
, m_fm_pw as pw
--, Round(m_fm_fp, 0) as fp
--, m_fm_dmg as dmg
, Round(m_fm_dur, 2) as dur
, m_fm_gain as gain
, m_fm_effi as effi
, Round(m_fm_dps, 2) as DPS
, Round(m_chargetime, 2) as charge

, m_cm
, m_cm_pw as pw
--, Round(m_cm_fp, 0) as fp
--, m_cm_dmg as dmg
, Round(m_cm_dur, 2) as dur
, m_cm_cost as cost
, m_cm_effi as effi

, TotalDPS
, KillTime
, DieTime
, lifespent as HP_spent
--, lifespent::text || '%' as HP_spent
--, Throughput

-- Q5 --------------------------------------------------------------------------
from(
select
*
, Round(m_totaldps, 2) as TotalDPS
, Round(t_lifetime, 1) as KillTime
, Round(m_lifetime, 1) as DieTime
, Round((t_lifetime / m_lifetime * 100), 1) as lifespent
, Round(m_throughput, 0) as Throughput

-- Q4 --------------------------------------------------------------------------
from(
select *
-- victim fighting life time
, m_lv30hp / t_totaldps as m_lifetime
-- victim lifetime output (over 100sec could not available)
, (case when m_lv30hp / t_totaldps > 100.0 then 100.0 else m_lv30hp / t_totaldps end) * m_totaldps as m_throughput

-- time to eliminate target
, t_lv30hp / m_totaldps as t_lifetime

-- Q3 --------------------------------------------------------------------------
from(
select *
-- total dps(fastmove until charge full + chargemove)
, (t_fm_dps * t_chargetime + t_cm_dmg) / (t_chargetime + t_cm_dur) as t_totaldps
, (m_fm_dps * m_chargetime + m_cm_dmg) / (m_chargetime + m_cm_dur) as m_totaldps


-- Q2 --------------------------------------------------------------------------
from(
select *
-- hp @ LV30 with IV=0
, Floor((t_st + 0.0) * 0.7317000031471252) * 2 as t_lv30hp
, Floor((m_st + 0.0) * 0.7317000031471252) as m_lv30hp
-- true firepower with effectiveness & stab
, (t_fm_pwstab * t_fm_effi)::numeric as t_fm_fp
, (t_cm_pwstab * t_cm_effi)::numeric as t_cm_fp
, (m_fm_pwstab * m_fm_effi)::numeric as m_fm_fp
, (m_cm_pwstab * m_cm_effi)::numeric as m_cm_fp
-- true DAMAGE with effectiveness & stab
, Floor((t_fm_pwstab * t_fm_effi / m_df)::numeric) + 1 as t_fm_dmg
, Floor((t_cm_pwstab * t_cm_effi / m_df * (case when '$DODGE'='false' then 1.0 else 0.25 end))::numeric) + 1 as t_cm_dmg
, Floor((m_fm_pwstab * m_fm_effi / t_df)::numeric) + 1 as m_fm_dmg
, Floor((m_cm_pwstab * m_cm_effi / t_df)::numeric) + 1 as m_cm_dmg
-- true DPS of Fastmove with effectiveness & stab
, (Floor((t_fm_pwstab * t_fm_effi / m_df)::numeric) + 1) / t_fm_dur as t_fm_dps
, (Floor((m_fm_pwstab * m_fm_effi / t_df)::numeric) + 1) / m_fm_dur as m_fm_dps
-- chargetime
, t_cm_cost / (t_fm_gain / t_fm_dur) as t_chargetime
, m_cm_cost / (m_fm_gain / m_fm_dur) as m_chargetime

-- Q1(raw query) --------------------------------------------------------------
from(
select

-- target pokemon as enemy (so each duration of moves increase 2.0 sec average)
  LOCALIZE_TARGET.jp as target
, LOCALIZE_TARGET_FASTMOVE.jp as t_fm
, LOCALIZE_TARGET_CHARGEMOVE.jp as t_cm
, TARGET.at as t_at
, TARGET.df as t_df
, TARGET.st as t_st
-- fastmove
, TARGET_FASTMOVE.power as t_fm_pw
, TARGET_FASTMOVE.firepower as t_fm_pwstab --firepower with stab
, (TARGET_FASTMOVE.duration + 2000)::numeric / 1000 as t_fm_dur
, TARGET_FASTMOVE.energy_gain as t_fm_gain
, TARGET_FAST_MP_1.multiplier * (case when ME.type2 is null then 1 else TARGET_FAST_MP_2.multiplier end) as t_fm_effi
-- chargemove
, TARGET_CHARGEMOVE.power as t_cm_pw
, TARGET_CHARGEMOVE.firepower as t_cm_pwstab -- firepower with stab
, (TARGET_CHARGEMOVE.duration + 2000)::numeric / 1000 as t_cm_dur
, TARGET_CHARGEMOVE.energy_cost as t_cm_cost
, TARGET_CHARGE_MP_1.multiplier * (case when ME.type2 is null then 1 else TARGET_CHARGE_MP_2.multiplier end) as t_cm_effi
-- legacy
, case when (TARGET_FASTMOVE.version & TARGET_CHARGEMOVE.version & B'1000')::int > 0 then null else 'Legacy' end as t_legacy

-- victim pokemon(s)
, LOCALIZE_ME.jp as me
, LOCALIZE_ME_FASTMOVE.jp as m_fm
, LOCALIZE_ME_CHARGEMOVE.jp as m_cm
, ME.at as m_at
, ME.df as m_df
, ME.st as m_st
-- fastmove
, ME_FASTMOVE.power as m_fm_pw
, ME_FASTMOVE.firepower::numeric as m_fm_pwstab --firepower with stab
, ME_FASTMOVE.duration::numeric / 1000 as m_fm_dur
, ME_FASTMOVE.energy_gain as m_fm_gain
, ME_FAST_MP_1.multiplier * (case when TARGET.type2 is null then 1 else ME_FAST_MP_2.multiplier end) as m_fm_effi
-- chargemove
, ME_CHARGEMOVE.power as m_cm_pw
, ME_CHARGEMOVE.firepower::numeric as m_cm_pwstab -- firepower with stab
, ME_CHARGEMOVE.duration::numeric / 1000 as m_cm_dur
, ME_CHARGEMOVE.energy_cost as m_cm_cost
, ME_CHARGE_MP_1.multiplier * (case when TARGET.type2 is null then 1 else ME_CHARGE_MP_2.multiplier end) as m_cm_effi
-- legacy
, case when (ME_FASTMOVE.version & ME_CHARGEMOVE.version & B'1000')::int > 0 then null else 'Legacy' end as m_legacy


-- tables ----------------------------------------------------------------------
-- 2 pokemons against each other
from pokemon.pokemon TARGET
join pokemon.pokemon ME on true

-- target pokemon details
join pokemon.view_firepower_fastmove TARGET_FASTMOVE on TARGET_FASTMOVE.pokemon_id = TARGET.id
join pokemon.view_firepower_chargemove TARGET_CHARGEMOVE on TARGET_CHARGEMOVE.pokemon_id = TARGET.id
left join pokemon.type TARGET_TYPE1 on TARGET_TYPE1.id=TARGET.type1
left join pokemon.type TARGET_TYPE2 on TARGET_TYPE2.id=TARGET.type2
join pokemon.multiplier TARGET_FAST_MP_1 on TARGET_FAST_MP_1.type_id_offense=TARGET_FASTMOVE.move_type and TARGET_FAST_MP_1.type_id_defense=ME.type1
left join pokemon.multiplier TARGET_FAST_MP_2 on TARGET_FAST_MP_2.type_id_offense=TARGET_FASTMOVE.move_type and TARGET_FAST_MP_2.type_id_defense=ME.type2
join pokemon.multiplier TARGET_CHARGE_MP_1 on TARGET_CHARGE_MP_1.type_id_offense=TARGET_CHARGEMOVE.move_type and TARGET_CHARGE_MP_1.type_id_defense=ME.type1
left join pokemon.multiplier TARGET_CHARGE_MP_2 on TARGET_CHARGE_MP_2.type_id_offense=TARGET_CHARGEMOVE.move_type and TARGET_CHARGE_MP_2.type_id_defense=ME.type2
-- localize for target pokemon
join pokemon.localize_pokemon LOCALIZE_TARGET on LOCALIZE_TARGET.id=TARGET.id
left join pokemon.localize_type LOCALIZE_TARGET_TYPE1 on LOCALIZE_TARGET_TYPE1.id=TARGET.type1
left join pokemon.localize_type LOCALIZE_TARGET_TYPE2 on LOCALIZE_TARGET_TYPE2.id=TARGET.type2
left join pokemon.localize_fastmove LOCALIZE_TARGET_FASTMOVE on LOCALIZE_TARGET_FASTMOVE.id=TARGET_FASTMOVE.move_id
left join pokemon.localize_chargemove LOCALIZE_TARGET_CHARGEMOVE on LOCALIZE_TARGET_CHARGEMOVE.id=TARGET_CHARGEMOVE.move_id
left join pokemon.localize_type LOCALIZE_TYPE_TARGET_FASTMOVE on LOCALIZE_TYPE_TARGET_FASTMOVE.id=TARGET_FASTMOVE.move_type
left join pokemon.localize_type LOCALIZE_TYPE_TARGET_CHARGEMOVE on LOCALIZE_TYPE_TARGET_CHARGEMOVE.id=TARGET_CHARGEMOVE.move_type

-- victim pokemon details
join pokemon.view_firepower_fastmove ME_FASTMOVE on ME_FASTMOVE.pokemon_id = ME.id
join pokemon.view_firepower_chargemove ME_CHARGEMOVE on ME_CHARGEMOVE.pokemon_id = ME.id
left join pokemon.type ME_TYPE1 on ME_TYPE1.id=ME.type1
left join pokemon.type ME_TYPE2 on ME_TYPE2.id=ME.type2
join pokemon.multiplier ME_FAST_MP_1 on ME_FAST_MP_1.type_id_offense=ME_FASTMOVE.move_type and ME_FAST_MP_1.type_id_defense=TARGET.type1
left join pokemon.multiplier ME_FAST_MP_2 on ME_FAST_MP_2.type_id_offense=ME_FASTMOVE.move_type and ME_FAST_MP_2.type_id_defense=TARGET.type2
join pokemon.multiplier ME_CHARGE_MP_1 on ME_CHARGE_MP_1.type_id_offense=ME_CHARGEMOVE.move_type and ME_CHARGE_MP_1.type_id_defense=TARGET.type1
left join pokemon.multiplier ME_CHARGE_MP_2 on ME_CHARGE_MP_2.type_id_offense=ME_CHARGEMOVE.move_type and ME_CHARGE_MP_2.type_id_defense=TARGET.type2
-- localize for challenger pokemon
join pokemon.localize_pokemon LOCALIZE_ME on LOCALIZE_ME.id=ME.id
left join pokemon.localize_type LOCALIZE_ME_TYPE1 on LOCALIZE_ME_TYPE1.id=ME.type1
left join pokemon.localize_type LOCALIZE_ME_TYPE2 on LOCALIZE_ME_TYPE2.id=ME.type2
left join pokemon.localize_fastmove LOCALIZE_ME_FASTMOVE on LOCALIZE_ME_FASTMOVE.id=ME_FASTMOVE.move_id
left join pokemon.localize_chargemove LOCALIZE_ME_CHARGEMOVE on LOCALIZE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_id
left join pokemon.localize_type LOCALIZE_TYPE_ME_FASTMOVE on LOCALIZE_TYPE_ME_FASTMOVE.id=ME_FASTMOVE.move_type
left join pokemon.localize_type LOCALIZE_TYPE_ME_CHARGEMOVE on LOCALIZE_TYPE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_type

-- conditions ------------------------------------------------------------------
WHERE true
--AND (TARGET_FASTMOVE.version & TARGET_CHARGEMOVE.version)::int > 0
AND TARGET_FASTMOVE.firepower is not null
--AND TARGET.id <> ALL (ARRAY[151,132,251])

--AND (ME_FASTMOVE.version & ME_CHARGEMOVE.version)::int > 0
AND ME_FASTMOVE.firepower is not null
--AND ME.id <> ALL (ARRAY[151,132,251])

AND LOCALIZE_TARGET.jp='$TARGET'
AND LOCALIZE_TARGET_FASTMOVE.jp='$TARGET_FASTMOVE'
AND LOCALIZE_TARGET_CHARGEMOVE.jp='$TARGET_CHARGEMOVE'

)Q1
)Q2
)Q3
)Q4
)Q5

join (
select
  avg(TotalDPS) as AVRG
, stddev(TotalDPS) as STDRD
from(
select
  Round(m_totaldps, 2) as TotalDPS
, Round(m_lifetime, 1) as DieTime
, Round(t_lifetime, 1) as KillTime
, Round((t_lifetime / m_lifetime * 100), 1) as lifespent
, Round(m_throughput, 0) as Throughput

-- T4 --------------------------------------------------------------------------
from(
select *
-- victim fighting life time
, m_lv30hp / t_totaldps as m_lifetime
-- victim lifetime output (over 100sec could not available)
, (case when m_lv30hp / t_totaldps > 100.0 then 100.0 else m_lv30hp / t_totaldps end) * m_totaldps as m_throughput
-- time to eliminate target
, t_lv30hp / m_totaldps as t_lifetime

-- T3 --------------------------------------------------------------------------
from(
select *
-- total dps(fastmove until charge full + chargemove)
, (t_fm_dps * t_chargetime + t_cm_dmg) / (t_chargetime + t_cm_dur) as t_totaldps
, (m_fm_dps * m_chargetime + m_cm_dmg) / (m_chargetime + m_cm_dur) as m_totaldps


-- T2 --------------------------------------------------------------------------
from(
select *
-- hp @ LV30 with IV=0
, Floor((t_st + 0.0) * 0.7317000031471252) * 2 as t_lv30hp
, Floor((m_st + 0.0) * 0.7317000031471252) as m_lv30hp
-- true DAMAGE with effectiveness & stab
, Floor((t_fm_pwstab * t_fm_effi / m_df)::numeric) + 1 as t_fm_dmg
, Floor((t_cm_pwstab * t_cm_effi / m_df * (case when '$DODGE'='false' then 1.0 else 0.25 end))::numeric) + 1 as t_cm_dmg
, Floor((m_fm_pwstab * m_fm_effi / t_df)::numeric) + 1 as m_fm_dmg
, Floor((m_cm_pwstab * m_cm_effi / t_df)::numeric) + 1 as m_cm_dmg
-- true DPS of Fastmove with effectiveness & stab
, (Floor((t_fm_pwstab * t_fm_effi / m_df)::numeric) + 1) / t_fm_dur as t_fm_dps
, (Floor((m_fm_pwstab * m_fm_effi / t_df)::numeric) + 1) / m_fm_dur as m_fm_dps
-- chargetime
, t_cm_cost / (t_fm_gain / t_fm_dur) as t_chargetime
, m_cm_cost / (m_fm_gain / m_fm_dur) as m_chargetime

-- T1(raw query) --------------------------------------------------------------
from(
select

-- target pokemon as enemy (so each duration of moves increase 2.0 sec average)
  LOCALIZE_TARGET.jp as target
, LOCALIZE_TARGET_FASTMOVE.jp as t_fm
, LOCALIZE_TARGET_CHARGEMOVE.jp as t_cm
, TARGET.at as t_at
, TARGET.df as t_df
, TARGET.st as t_st
-- fastmove
, TARGET_FASTMOVE.power as t_fm_pw
, TARGET_FASTMOVE.firepower as t_fm_pwstab --firepower with stab
, (TARGET_FASTMOVE.duration + 2000)::numeric / 1000 as t_fm_dur
, TARGET_FASTMOVE.energy_gain as t_fm_gain
, TARGET_FAST_MP_1.multiplier * (case when ME.type2 is null then 1 else TARGET_FAST_MP_2.multiplier end) as t_fm_effi
-- chargemove
, TARGET_CHARGEMOVE.power as t_cm_pw
, TARGET_CHARGEMOVE.firepower as t_cm_pwstab -- firepower with stab
, (TARGET_CHARGEMOVE.duration + 2000)::numeric / 1000 as t_cm_dur
, TARGET_CHARGEMOVE.energy_cost as t_cm_cost
, TARGET_CHARGE_MP_1.multiplier * (case when ME.type2 is null then 1 else TARGET_CHARGE_MP_2.multiplier end) as t_cm_effi
-- legacy
, case when (TARGET_FASTMOVE.version & TARGET_CHARGEMOVE.version & B'1000')::int > 0 then null else 'Legacy' end as t_legacy

-- victim pokemon(s)
, LOCALIZE_ME.jp as me
, LOCALIZE_ME_FASTMOVE.jp as m_fm
, LOCALIZE_ME_CHARGEMOVE.jp as m_cm
, ME.at as m_at
, ME.df as m_df
, ME.st as m_st
-- fastmove
, ME_FASTMOVE.power as m_fm_pw
, ME_FASTMOVE.firepower::numeric as m_fm_pwstab --firepower with stab
, ME_FASTMOVE.duration::numeric / 1000 as m_fm_dur
, ME_FASTMOVE.energy_gain as m_fm_gain
, ME_FAST_MP_1.multiplier * (case when TARGET.type2 is null then 1 else ME_FAST_MP_2.multiplier end) as m_fm_effi
-- chargemove
, ME_CHARGEMOVE.power as m_cm_pw
, ME_CHARGEMOVE.firepower::numeric as m_cm_pwstab -- firepower with stab
, ME_CHARGEMOVE.duration::numeric / 1000 as m_cm_dur
, ME_CHARGEMOVE.energy_cost as m_cm_cost
, ME_CHARGE_MP_1.multiplier * (case when TARGET.type2 is null then 1 else ME_CHARGE_MP_2.multiplier end) as m_cm_effi
-- legacy
, case when (ME_FASTMOVE.version & ME_CHARGEMOVE.version & B'1000')::int > 0 then null else 'Legacy' end as m_legacy


-- tables ----------------------------------------------------------------------
-- 2 pokemons against each other
from pokemon.pokemon TARGET
join pokemon.pokemon ME on true

-- target pokemon details
join pokemon.view_firepower_fastmove TARGET_FASTMOVE on TARGET_FASTMOVE.pokemon_id = TARGET.id
join pokemon.view_firepower_chargemove TARGET_CHARGEMOVE on TARGET_CHARGEMOVE.pokemon_id = TARGET.id
left join pokemon.type TARGET_TYPE1 on TARGET_TYPE1.id=TARGET.type1
left join pokemon.type TARGET_TYPE2 on TARGET_TYPE2.id=TARGET.type2
join pokemon.multiplier TARGET_FAST_MP_1 on TARGET_FAST_MP_1.type_id_offense=TARGET_FASTMOVE.move_type and TARGET_FAST_MP_1.type_id_defense=ME.type1
left join pokemon.multiplier TARGET_FAST_MP_2 on TARGET_FAST_MP_2.type_id_offense=TARGET_FASTMOVE.move_type and TARGET_FAST_MP_2.type_id_defense=ME.type2
join pokemon.multiplier TARGET_CHARGE_MP_1 on TARGET_CHARGE_MP_1.type_id_offense=TARGET_CHARGEMOVE.move_type and TARGET_CHARGE_MP_1.type_id_defense=ME.type1
left join pokemon.multiplier TARGET_CHARGE_MP_2 on TARGET_CHARGE_MP_2.type_id_offense=TARGET_CHARGEMOVE.move_type and TARGET_CHARGE_MP_2.type_id_defense=ME.type2
-- localize for target pokemon
join pokemon.localize_pokemon LOCALIZE_TARGET on LOCALIZE_TARGET.id=TARGET.id
left join pokemon.localize_type LOCALIZE_TARGET_TYPE1 on LOCALIZE_TARGET_TYPE1.id=TARGET.type1
left join pokemon.localize_type LOCALIZE_TARGET_TYPE2 on LOCALIZE_TARGET_TYPE2.id=TARGET.type2
left join pokemon.localize_fastmove LOCALIZE_TARGET_FASTMOVE on LOCALIZE_TARGET_FASTMOVE.id=TARGET_FASTMOVE.move_id
left join pokemon.localize_chargemove LOCALIZE_TARGET_CHARGEMOVE on LOCALIZE_TARGET_CHARGEMOVE.id=TARGET_CHARGEMOVE.move_id
left join pokemon.localize_type LOCALIZE_TYPE_TARGET_FASTMOVE on LOCALIZE_TYPE_TARGET_FASTMOVE.id=TARGET_FASTMOVE.move_type
left join pokemon.localize_type LOCALIZE_TYPE_TARGET_CHARGEMOVE on LOCALIZE_TYPE_TARGET_CHARGEMOVE.id=TARGET_CHARGEMOVE.move_type

-- victim pokemon details
join pokemon.view_firepower_fastmove ME_FASTMOVE on ME_FASTMOVE.pokemon_id = ME.id
join pokemon.view_firepower_chargemove ME_CHARGEMOVE on ME_CHARGEMOVE.pokemon_id = ME.id
left join pokemon.type ME_TYPE1 on ME_TYPE1.id=ME.type1
left join pokemon.type ME_TYPE2 on ME_TYPE2.id=ME.type2
join pokemon.multiplier ME_FAST_MP_1 on ME_FAST_MP_1.type_id_offense=ME_FASTMOVE.move_type and ME_FAST_MP_1.type_id_defense=TARGET.type1
left join pokemon.multiplier ME_FAST_MP_2 on ME_FAST_MP_2.type_id_offense=ME_FASTMOVE.move_type and ME_FAST_MP_2.type_id_defense=TARGET.type2
join pokemon.multiplier ME_CHARGE_MP_1 on ME_CHARGE_MP_1.type_id_offense=ME_CHARGEMOVE.move_type and ME_CHARGE_MP_1.type_id_defense=TARGET.type1
left join pokemon.multiplier ME_CHARGE_MP_2 on ME_CHARGE_MP_2.type_id_offense=ME_CHARGEMOVE.move_type and ME_CHARGE_MP_2.type_id_defense=TARGET.type2
-- localize for challenger pokemon
join pokemon.localize_pokemon LOCALIZE_ME on LOCALIZE_ME.id=ME.id
left join pokemon.localize_type LOCALIZE_ME_TYPE1 on LOCALIZE_ME_TYPE1.id=ME.type1
left join pokemon.localize_type LOCALIZE_ME_TYPE2 on LOCALIZE_ME_TYPE2.id=ME.type2
left join pokemon.localize_fastmove LOCALIZE_ME_FASTMOVE on LOCALIZE_ME_FASTMOVE.id=ME_FASTMOVE.move_id
left join pokemon.localize_chargemove LOCALIZE_ME_CHARGEMOVE on LOCALIZE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_id
left join pokemon.localize_type LOCALIZE_TYPE_ME_FASTMOVE on LOCALIZE_TYPE_ME_FASTMOVE.id=ME_FASTMOVE.move_type
left join pokemon.localize_type LOCALIZE_TYPE_ME_CHARGEMOVE on LOCALIZE_TYPE_ME_CHARGEMOVE.id=ME_CHARGEMOVE.move_type

-- conditions ------------------------------------------------------------------
WHERE true
--AND (TARGET_FASTMOVE.version & TARGET_CHARGEMOVE.version)::int > 0
AND TARGET_FASTMOVE.firepower is not null
--AND TARGET.id <> ALL (ARRAY[151,132,251])

--AND (ME_FASTMOVE.version & ME_CHARGEMOVE.version)::int > 0
AND ME_FASTMOVE.firepower is not null
--AND ME.id <> ALL (ARRAY[151,132,251])

AND LOCALIZE_TARGET.jp='$TARGET'
AND LOCALIZE_TARGET_FASTMOVE.jp='$TARGET_FASTMOVE'
AND LOCALIZE_TARGET_CHARGEMOVE.jp='$TARGET_CHARGEMOVE'

)T1
)T2
)T3
)T4
)T5
)T6 on true

WHERE true
$MEONLY
and ROUND((TotalDPS - AVRG) / STDRD * 10 + 50, 1) > 70.0
--and killtime < 99.9
--and (TotalDPS - AVRG) / STDRD * 10 + 50 > 60.0

order by lifespent
--order by KillTime
limit $LIMIT
;

_EOS_
)

echo "${SQL}" | $PSQL_COMMAND
exit 0
