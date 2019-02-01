#!/bin/bash
#
# [usage]
# $ ./import_game_master.sh <target_schema> <working_dir> <psql_command>
#
# $ ./import_game_master.sh POKEMON . "psql postgres"

SCHEMA=$1
WORKING_DIR=$2
PSQL_COMMAND=$3
[ $# -ne 3 ] && echo "[usage] $ import_game_master.sh <target_schema> <WORKING_DIR> <psql_command>" && exit 1
echo "Target schema: ${SCHEMA}"

CSV_OUTPUT_DIR="CSV_OUTPUT/2017-11-02"
CSV_STATIC_DIR="CSV_STATIC"



# define source files
POKEMON_FILE="${WORKING_DIR}/${CSV_OUTPUT_DIR}/pokemon.csv"
TYPE_FILE="${WORKING_DIR}/${CSV_OUTPUT_DIR}/type.csv"
MULTIPLIER_FILE="${WORKING_DIR}/${CSV_OUTPUT_DIR}/multiplier.csv"
CP_MULTIPLIER_FILE="${WORKING_DIR}/${CSV_OUTPUT_DIR}/cp_multiplier.csv"
FASTMOVE_FILE="${WORKING_DIR}/${CSV_OUTPUT_DIR}/fastmove.csv"
CHARGEMOVE_FILE="${WORKING_DIR}/${CSV_OUTPUT_DIR}/chargemove.csv"
#moves(including legacy)
POKEMON_TO_FASTMOVE_20160706_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_fastmove_2016-07-06.csv"
POKEMON_TO_CHARGEMOVE_20160706_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_chargemove_2016-07-06.csv"
POKEMON_TO_FASTMOVE_20160819_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_fastmove_2016-08-19.csv"
POKEMON_TO_CHARGEMOVE_20160819_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_chargemove_2016-08-19.csv"
POKEMON_TO_FASTMOVE_20170216_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_fastmove_2017-02-16.csv"
POKEMON_TO_CHARGEMOVE_20170216_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_chargemove_2017-02-16.csv"
POKEMON_TO_FASTMOVE_20171102_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_fastmove_2017-11-02.csv"
POKEMON_TO_CHARGEMOVE_20171102_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/pokemon_to_chargemove_2017-11-02.csv"
#other static files
FASTMOVE_OLD_TO_NEW_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/fastmove_old_to_new.csv"
CHARGEMOVE_OLD_TO_NEW_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/chargemove_old_to_new.csv"
LOCALIZE_FASTMOVE_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/localize_fastmove.csv"
LOCALIZE_CHARGEMOVE_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/localize_chargemove.csv"
LOCALIZE_TYPE_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/localize_type.csv"
LOCALIZE_POKEMON_FILE="${WORKING_DIR}/${CSV_STATIC_DIR}/localize_pokemon.csv"

# define tables
POKEMON_TABLE="${SCHEMA}.pokemon"
TYPE_TABLE="${SCHEMA}.type"
MULTIPLIER_TABLE="${SCHEMA}.multiplier"
CP_MULTIPLIER_TABLE="${SCHEMA}.cp_multiplier"
FASTMOVE_TABLE="${SCHEMA}.fastmove"
CHARGEMOVE_TABLE="${SCHEMA}.chargemove"
POKEMON_TO_FASTMOVE_TABLE="${SCHEMA}.pokemon_to_fastmove"
POKEMON_TO_CHARGEMOVE_TABLE="${SCHEMA}.pokemon_to_chargemove"
FASTMOVE_OLD_TO_NEW_TABLE="${SCHEMA}.fastmove_old_to_new"
CHARGEMOVE_OLD_TO_NEW_TABLE="${SCHEMA}.chargemove_old_to_new"
LOCALIZE_FASTMOVE_TABLE="${SCHEMA}.localize_fastmove"
LOCALIZE_CHARGEMOVE_TABLE="${SCHEMA}.localize_chargemove"
LOCALIZE_TYPE_TABLE="${SCHEMA}.localize_type"
LOCALIZE_POKEMON_TABLE="${SCHEMA}.localize_pokemon"

# define views
POKEMON_TO_FASTMOVE_VIEW="${SCHEMA}.view_pokemon_to_fastmove"
POKEMON_TO_CHARGEMOVE_VIEW="${SCHEMA}.view_pokemon_to_chargemove"
FIREPOWER_FASTMOVE_VIEW="${SCHEMA}.view_firepower_fastmove"
FIREPOWER_CHARGEMOVE_VIEW="${SCHEMA}.view_firepower_chargemove"



# import to PostgreSQL
SQL=$(cat << _EOS_
BEGIN;

drop table if exists $POKEMON_TABLE cascade;
drop table if exists $TYPE_TABLE cascade;
drop table if exists $MULTIPLIER_TABLE cascade;
drop table if exists $CP_MULTIPLIER_TABLE cascade;
drop table if exists $FASTMOVE_TABLE cascade;
drop table if exists $CHARGEMOVE_TABLE cascade;
drop table if exists $POKEMON_TO_FASTMOVE_TABLE cascade;
drop table if exists $POKEMON_TO_CHARGEMOVE_TABLE cascade;
drop table if exists $FASTMOVE_OLD_TO_NEW_TABLE cascade;
drop table if exists $CHARGEMOVE_OLD_TO_NEW_TABLE cascade;
drop table if exists $LOCALIZE_FASTMOVE_TABLE cascade;
drop table if exists $LOCALIZE_CHARGEMOVE_TABLE cascade;
drop table if exists $LOCALIZE_TYPE_TABLE cascade;
drop table if exists $LOCALIZE_POKEMON_TABLE cascade;

create table $POKEMON_TABLE (id integer,codename text,type1 integer,type2 integer, at integer, df integer, st integer);
create table $TYPE_TABLE (id integer,codename text);
create table $MULTIPLIER_TABLE (type_id_offense integer, type_id_defense integer, multiplier real);
create table $CP_MULTIPLIER_TABLE (lv real, multiplier real);
create table $FASTMOVE_TABLE (id integer, codename text, type integer, power integer, duration integer, energy_gain integer, damage_window_start integer, damage_window_end integer);
create table $CHARGEMOVE_TABLE (id integer, codename text, type integer, power integer, duration integer, energy_cost integer, damage_window_start integer, damage_window_end integer);
create table $POKEMON_TO_FASTMOVE_TABLE (pokemon_id integer, move_id integer, version date);
create table $POKEMON_TO_CHARGEMOVE_TABLE (pokemon_id integer, move_id integer, version date);
create table $FASTMOVE_OLD_TO_NEW_TABLE (old_id integer,new_id integer);
create table $CHARGEMOVE_OLD_TO_NEW_TABLE (old_id integer,new_id integer);
create table $LOCALIZE_FASTMOVE_TABLE (id integer, codename text, en text, jp text);
create table $LOCALIZE_CHARGEMOVE_TABLE (id integer, codename text, en text, jp text);
create table $LOCALIZE_TYPE_TABLE (id integer, codename text, en text, jp text);
create table $LOCALIZE_POKEMON_TABLE (id integer, codename text, en text, jp text);

\copy $POKEMON_TABLE (id, codename, type1, type2, at, df, st) from '${POKEMON_FILE}' with CSV NULL 'null';
\copy $TYPE_TABLE (id, codename) from '${TYPE_FILE}' with CSV NULL 'null';
\copy $MULTIPLIER_TABLE (type_id_offense, type_id_defense, multiplier) from '${MULTIPLIER_FILE}' with CSV NULL 'null';
\copy $CP_MULTIPLIER_TABLE (lv, multiplier) from '${CP_MULTIPLIER_FILE}' with CSV NULL 'null';
\copy $FASTMOVE_TABLE (id, codename, type, power, duration, energy_gain, damage_window_start, damage_window_end) from '${FASTMOVE_FILE}' with CSV NULL 'null';
\copy $CHARGEMOVE_TABLE (id, codename, type, power, duration, energy_cost, damage_window_start, damage_window_end) from '${CHARGEMOVE_FILE}' with CSV NULL 'null';

\copy $POKEMON_TO_FASTMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_FASTMOVE_20160706_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_CHARGEMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_CHARGEMOVE_20160706_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_FASTMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_FASTMOVE_20160819_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_CHARGEMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_CHARGEMOVE_20160819_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_FASTMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_FASTMOVE_20170216_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_CHARGEMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_CHARGEMOVE_20170216_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_FASTMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_FASTMOVE_20171102_FILE}' with CSV NULL 'null';
\copy $POKEMON_TO_CHARGEMOVE_TABLE (pokemon_id, move_id, version) from '${POKEMON_TO_CHARGEMOVE_20171102_FILE}' with CSV NULL 'null';

\copy $FASTMOVE_OLD_TO_NEW_TABLE (old_id, new_id) from '${FASTMOVE_OLD_TO_NEW_FILE}' with CSV NULL 'null';
\copy $CHARGEMOVE_OLD_TO_NEW_TABLE (old_id, new_id) from '${CHARGEMOVE_OLD_TO_NEW_FILE}' with CSV NULL 'null';

\copy $LOCALIZE_FASTMOVE_TABLE (id,codename,en,jp) from '${LOCALIZE_FASTMOVE_FILE}' with CSV HEADER NULL 'null';
\copy $LOCALIZE_CHARGEMOVE_TABLE (id,codename,en,jp) from '${LOCALIZE_CHARGEMOVE_FILE}' with CSV HEADER NULL 'null';
\copy $LOCALIZE_TYPE_TABLE (id,codename,en,jp) from '${LOCALIZE_TYPE_FILE}' with CSV HEADER NULL 'null';
\copy $LOCALIZE_POKEMON_TABLE (id,codename,en,jp) from '${LOCALIZE_POKEMON_FILE}' with CSV HEADER NULL 'null';


drop view if exists $POKEMON_TO_FASTMOVE_VIEW;
create view $POKEMON_TO_FASTMOVE_VIEW as
select
  pokemon_id
, move_id
, (
    max(case when version='2016-07-06' then 1 else 0 end)
  + max(case when version='2016-08-19' then 2 else 0 end)
  + max(case when version='2017-02-16' then 4 else 0 end)
  + max(case when version='2017-11-02' then 8 else 0 end)
)::bit(4) as version
from $POKEMON_TO_FASTMOVE_TABLE
group by pokemon_id, move_id
order by pokemon_id, move_id;


drop view if exists $POKEMON_TO_CHARGEMOVE_VIEW;
create view $POKEMON_TO_CHARGEMOVE_VIEW as
select
  pokemon_id
, move_id
, (
    max(case when version='2016-07-06' then 1 else 0 end)
  + max(case when version='2016-08-19' then 2 else 0 end)
  + max(case when version='2017-02-16' then 4 else 0 end)
  + max(case when version='2017-11-02' then 8 else 0 end)
)::bit(4) as version
from $POKEMON_TO_CHARGEMOVE_TABLE
group by pokemon_id, move_id
order by pokemon_id, move_id;




drop view if exists $FIREPOWER_FASTMOVE_VIEW ;
create view $FIREPOWER_FASTMOVE_VIEW as
select
PF.pokemon_id,
PF.move_id,
PF.version,
P.type1 as pokemon_type1,
P.type2 as pokemon_type2,
P.at,
M.power,
M.type as move_type,
M.duration,
M.energy_gain,
(CASE WHEN P.type1 = M.type OR P.type2 = M.type THEN 1.2 ELSE 1.0 END)::double precision as STAB,
(0.5*M.power*P.at*(CASE WHEN P.type1 = M.type OR P.type2 = M.type THEN 1.2 ELSE 1.0 END))::double precision as firepower
from $POKEMON_TO_FASTMOVE_VIEW PF
join $POKEMON_TABLE P on P.id=PF.pokemon_id
join $FASTMOVE_TABLE M on M.id=PF.move_id
;


drop view if exists $FIREPOWER_CHARGEMOVE_VIEW ;
create view $FIREPOWER_CHARGEMOVE_VIEW as
select
PC.pokemon_id,
PC.move_id,
PC.version,
P.type1 as pokemon_type1,
P.type2 as pokemon_type2,
P.at,
M.power,
M.type as move_type,
M.duration,
M.energy_cost,
(CASE WHEN P.type1 = M.type OR P.type2 = M.type THEN 1.2 ELSE 1.0 END)::double precision as STAB,
(0.5*M.power*P.at*(CASE WHEN P.type1 = M.type OR P.type2 = M.type THEN 1.2 ELSE 1.0 END))::double precision as firepower
from $POKEMON_TO_CHARGEMOVE_VIEW PC
join $POKEMON_TABLE P on P.id=PC.pokemon_id
join $CHARGEMOVE_TABLE M on M.id=PC.move_id
;




COMMIT;
_EOS_
)

echo "${SQL}" | ${PSQL_COMMAND}


exit 0
