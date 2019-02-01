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
FAST_MOVE as (
  select
    MON2MOVE.pokemon_id,
    MON2MOVE.move_id as fm_id,
    MOVE_LCL.jp as fm_name_jp,
    MOVE_LCL.en as fm_name_en,
    MON2MOVE.version as fm_version,
    MOVE.power as fm_power,
    MOVE.type as fm_type,
    TYPE_LCL.jp as fm_type_jp,
    TYPE_LCL.en as fm_type_en,
    MOVE.duration::Float / 1000 as fm_duration,
    MOVE.energy_gain as fm_gain,
    (CASE WHEN MON.type1 = MOVE.type OR MON.type2 = MOVE.type THEN 1.2 ELSE 1.0 END)::double precision as fm_STAB,
    (CASE WHEN (MON2MOVE.version & B'1000')::int > 0 then null else 'X' end) as fm_legacy
  from pokemon.view_pokemon_to_fastmove MON2MOVE
  join MON on MON.id=MON2MOVE.pokemon_id
  join pokemon.fastmove MOVE on MOVE.id=MON2MOVE.move_id
  join pokemon.localize_fastmove MOVE_LCL on MOVE_LCL.id=MON2MOVE.move_id
  join pokemon.localize_type TYPE_LCL on TYPE_LCL.id=MOVE.type
  where MOVE.power is not null
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
)
select
id, name_jp, name_en, type1_jp,type2_jp,
fm_name_jp,fm_type_jp,fm_STAB as stab, fm_legacy as x,
cm_name_jp,cm_type_jp,cm_STAB as stab, cm_legacy as x
from ALL_MON
where true
AND name_jp='ギャラドス';
