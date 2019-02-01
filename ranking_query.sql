WITH
MON as (
  select
    MON.id,
    MON_LCL.jp as name_jp,
    MON_LCL.en as name_en,
    MON.type1,
    TYPE_LCL1.jp as type1_jp,
    TYPE_LCL1.en as type1_en,
    MON.type2,
    TYPE_LCL2.jp as type2_jp,
    TYPE_LCL2.en as type2_en,
    MON.at,
    MON.df,
    MON.st
  from pokemon.pokemon MON
  join pokemon.localize_pokemon MON_LCL on MON_LCL.id=MON.id
  left join pokemon.localize_type TYPE_LCL1 on TYPE_LCL1.id=MON.type1
  left join pokemon.localize_type TYPE_LCL2 on TYPE_LCL2.id=MON.type2
),
FAST_MOVE_PRE as (
  select
    MON.type1,MON.type2,
    MON2MOVE.pokemon_id,
    MON2MOVE.move_id as fm_id,
    MOVE_LCL.jp as fm_name_jp,
    MOVE_LCL.en as fm_name_en,
    MON2MOVE.version as fm_version,
    MOVE.power as fm_power,
    -- case the move is "HIDDEN_POWER" its type is same as pokemon type 1
    (CASE WHEN MON2MOVE.move_id = 281 THEN MON.type1 ELSE MOVE.type END) as fm_type,
    MOVE.duration::Float / 1000 as fm_duration,
    MOVE.energy_gain as fm_gain,
    (CASE WHEN (MON2MOVE.version & B'1000')::int > 0 then null else 'X' end) as fm_legacy
  from pokemon.view_pokemon_to_fastmove MON2MOVE
  join MON on MON.id=MON2MOVE.pokemon_id
  join pokemon.fastmove MOVE on MOVE.id=MON2MOVE.move_id
  join pokemon.localize_fastmove MOVE_LCL on MOVE_LCL.id=MON2MOVE.move_id
  where MOVE.power is not null
),
FAST_MOVE as (
  select
    pokemon_id,fm_id,fm_name_jp,fm_name_en,fm_version,fm_power,
    fm_type,
    TYPE_LCL.jp as fm_type_jp,
    TYPE_LCL.en as fm_type_en,
    fm_duration,
    fm_gain,
    (CASE WHEN type1 = fm_type OR type2 = fm_type THEN 1.2 ELSE 1.0 END)::double precision as fm_STAB,
    fm_legacy
    from FAST_MOVE_PRE
  join pokemon.localize_type TYPE_LCL on TYPE_LCL.id=FAST_MOVE_PRE.fm_type
),
CHARGE_MOVE as (
  select
    MON2MOVE.pokemon_id,
    MON2MOVE.move_id as cm_id,
    MOVE_LCL.jp as cm_name_jp,
    MOVE_LCL.en as cm_name_en,
    MON2MOVE.version as cm_version,
    MOVE.power as cm_power,
    MOVE.type as cm_type,
    TYPE_LCL.jp as cm_type_jp,
    TYPE_LCL.en as cm_type_en,
    MOVE.duration::Float / 1000 as cm_duration,
    MOVE.energy_cost as cm_cost,
    (CASE WHEN MON.type1 = MOVE.type OR MON.type2 = MOVE.type THEN 1.2 ELSE 1.0 END)::double precision as cm_STAB,
    (CASE WHEN (MON2MOVE.version & B'1000')::int > 0 then null else 'X' end) as cm_legacy
  from pokemon.view_pokemon_to_chargemove MON2MOVE
  join MON on MON.id=MON2MOVE.pokemon_id
  join pokemon.chargemove MOVE on MOVE.id=MON2MOVE.move_id
  join pokemon.localize_chargemove MOVE_LCL on MOVE_LCL.id=MON2MOVE.move_id
  join pokemon.localize_type TYPE_LCL on TYPE_LCL.id=MOVE.type
  where MOVE.power is not null
),
ALL_MON as (
  select *
  from MON
  join FAST_MOVE on FAST_MOVE.pokemon_id=MON.id
  join CHARGE_MOVE on CHARGE_MOVE.pokemon_id=MON.id
  where MON.id <> ALL (ARRAY[
    132,
    --150,
    151,
    225,
    235,
    --243,244,245,
    --249,
    250,
    251
  ]) -- 251:Celebi,250:Ho-Oh,249:Lugia,245:Suicune,244:Entei,243:Raikou,235:Smeargle,225:Delibird,151:Mew,150:Mewtwo,132:Ditto
),
TARGET_MON as (
  select *
  from ALL_MON
  where true
  AND name_jp='ハピナス'
  AND fm_name_jp='はたく'
  AND cm_name_jp='マジカルシャイン'
),
FM_EFFICIENCY as (
select * from(
  select
    ALL_MON.id as id
  , ALL_MON.fm_name_jp as fm_name_jp
  , MP1.multiplier * (case when TARGET_MON.type2 is null then 1 else MP2.multiplier end) as efficiency
    from ALL_MON
    join TARGET_MON on true
    join pokemon.multiplier as MP1 on MP1.type_id_offense=ALL_MON.fm_type and MP1.type_id_defense=TARGET_MON.type1
    left join pokemon.multiplier as MP2 on MP2.type_id_offense=ALL_MON.fm_type and MP2.type_id_defense=TARGET_MON.type2
  ) SQ group by id,fm_name_jp,efficiency
),
CM_EFFICIENCY as (
select * from(
  select
    ALL_MON.id as id
  , ALL_MON.cm_name_jp as cm_name_jp
  , MP1.multiplier * (case when TARGET_MON.type2 is null then 1 else MP2.multiplier end) as efficiency
    from ALL_MON
    join TARGET_MON on true
    join pokemon.multiplier as MP1 on MP1.type_id_offense=ALL_MON.cm_type and MP1.type_id_defense=TARGET_MON.type1
    left join pokemon.multiplier as MP2 on MP2.type_id_offense=ALL_MON.cm_type and MP2.type_id_defense=TARGET_MON.type2
  ) SQ group by id,cm_name_jp,efficiency
),
SIMULATION as (
select
  --*
  ALL_MON.id
, ALL_MON.name_jp
--, ALL_MON.type1_jp
--, ALL_MON.type2_jp
, ALL_MON.fm_name_jp
, ALL_MON.cm_name_jp
, ALL_MON.at
, ALL_MON.fm_power
, ALL_MON.fm_STAB
, ALL_MON.fm_duration
, FM_EFFICIENCY.efficiency as fm_effi
, ALL_MON.at * ALL_MON.fm_power * ALL_MON.fm_STAB * FM_EFFICIENCY.efficiency * 0.5 as fm_firepower
, (ALL_MON.at * ALL_MON.fm_power * ALL_MON.fm_STAB * FM_EFFICIENCY.efficiency * 0.5)/ALL_MON.fm_duration as fm_dps
, (ALL_MON.cm_cost / (ALL_MON.fm_gain::Float / ALL_MON.fm_duration)) as fm_chargetime
, ((ALL_MON.at * ALL_MON.fm_power * ALL_MON.fm_STAB * FM_EFFICIENCY.efficiency * 0.5)/ALL_MON.fm_duration)
  * (ALL_MON.cm_cost / (ALL_MON.fm_gain::Float / ALL_MON.fm_duration))
  + (ALL_MON.at * ALL_MON.cm_power * ALL_MON.cm_STAB * CM_EFFICIENCY.efficiency * 0.5)
  as cycle_output
, (((ALL_MON.at * ALL_MON.fm_power * ALL_MON.fm_STAB * FM_EFFICIENCY.efficiency * 0.5)/ALL_MON.fm_duration)
    * (ALL_MON.cm_cost / (ALL_MON.fm_gain::Float / ALL_MON.fm_duration))
    + (ALL_MON.at * ALL_MON.cm_power * ALL_MON.cm_STAB * CM_EFFICIENCY.efficiency * 0.5)
  ) / (ALL_MON.cm_cost / (ALL_MON.fm_gain::Float / ALL_MON.fm_duration) + ALL_MON.cm_duration)
  as cycle_dps
, ALL_MON.cm_power
, ALL_MON.cm_STAB
, ALL_MON.cm_duration
, CM_EFFICIENCY.efficiency as cm_effi
, ALL_MON.at * ALL_MON.cm_power * ALL_MON.cm_STAB * CM_EFFICIENCY.efficiency * 0.5 as cm_firepower
--, TARGET_MON.name_jp
--, TARGET_MON.fm_name_jp
--, TARGET_MON.cm_name_jp
from ALL_MON
join TARGET_MON on true
join FM_EFFICIENCY on ALL_MON.id=FM_EFFICIENCY.id and ALL_MON.fm_name_jp=FM_EFFICIENCY.fm_name_jp
join CM_EFFICIENCY on ALL_MON.id=CM_EFFICIENCY.id and ALL_MON.cm_name_jp=CM_EFFICIENCY.cm_name_jp
--where ALL_MON.name_jp='スイクン'
),
SIM1_RANK as(
  select
    row_number() OVER (ORDER BY cycle_dps desc) AS rank
  , ROUND((cycle_dps - avg(cycle_dps)) / stddev(cycle_dps) * 10 + 50, 1) as T
  , name_jp
  , fm_name_jp
  , fm_name_jp
  from SIMULATION
)
select * from SIM1_RANK
--order by cycle_dps desc
;
