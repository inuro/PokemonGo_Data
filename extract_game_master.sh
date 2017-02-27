#!/bin/bash
# Extract GAME_MASTER.json(converted from Protobuf binary) into CSV file for SQL import
#
# [usage]
# $ extract_game_master.sh <GAME_MASTER_JSON>
# $ ./extract_game_master.sh game_master.json

LOCALFILE=$1
#OUTPUTDIR=$2
OUTPUTDIR=CSV_OUTPUT
[ $# -ne 1 ] && echo "[usage] $ extract_game_master.sh <game_master.json>" && exit 1
echo "Source file: ${LOCALFILE}"
echo "Output dir: ${OUTPUTDIR}"


# Pokemon data
# [header]
# pokemonId,codename,type_1,type_2(may null),base_attack,base_defense,base_stamina
POKEMON_FILE="${OUTPUTDIR}/pokemon.csv"
echo "Pokemon base stats: ${POKEMON_FILE}"

cat ${LOCALFILE} |
jq -c '.itemTemplates[] | select(.templateId | test("^V[0-9]+_POKEMON_")) |
[
.pokemonSettings.pokemonId,
(.templateId | capture("^V[0-9]+_POKEMON_(?<name>.+)$").name),
(.pokemonSettings |
   .type,
   .type_2,
   .stats.baseAttack,
   .stats.baseDefense,
   .stats.baseStamina
)
]' | sed -E 's/^\[//g' | sed -E 's/\]$//g' > ${POKEMON_FILE}



# Pokemon->Quickmove data(current)
# [header]
# pokemonId,move_id,version(date)
POKEMON_TO_FASTMOVE_FILE="${OUTPUTDIR}/pokemon_to_fastmove_2017-02-16.csv"
echo "Pokemon to Fastmove(current): ${POKEMON_TO_FASTMOVE_FILE}"

cat ${LOCALFILE} |
jq -r -c '.itemTemplates[] | select(.templateId | test("^V[0-9]+_POKEMON_")) |
.pokemonSettings.pokemonId as $id |
(.templateId | capture("^V[0-9]+_POKEMON_(?<name>.+)$").name) as $name |
.pokemonSettings.quickMoves[] | [$id, ., "2017-02-16"]
'| sed -E 's/^\[//g' | sed -E 's/\]$//g' | sed -E 's/"//g' > ${POKEMON_TO_FASTMOVE_FILE}



# Pokemon->Chargemove data(current)
# [header]
# pokemonId,move_id,version(date)
POKEMON_TO_CHARGEMOVE_FILE="${OUTPUTDIR}/pokemon_to_chargemove_2017-02-16.csv"
echo "Pokemon to Chargemove(current): ${POKEMON_TO_CHARGEMOVE_FILE}"

cat ${LOCALFILE} |
jq -r -c '.itemTemplates[] | select(.templateId | test("^V[0-9]+_POKEMON_")) |
.pokemonSettings.pokemonId as $id |
(.templateId | capture("^V[0-9]+_POKEMON_(?<name>.+)$").name) as $name |
.pokemonSettings.cinematicMoves[] | [$id, ., "2017-02-16"]
'| sed -E 's/^\[//g' | sed -E 's/\]$//g' | sed -E 's/"//g' > ${POKEMON_TO_CHARGEMOVE_FILE}



# Fastmove data
# [header]
# move_id,codename,move_type,power,duration,energy,damage_window_start,damage_window_end
FASTMOVE_FILE="${OUTPUTDIR}/fastmove.csv"
echo "Fastmove: ${FASTMOVE_FILE}"

cat ${LOCALFILE} |
jq -c '.itemTemplates[] | select(.templateId | test("^V[0-9]+_MOVE_")) |
select(.moveSettings.energyDelta > 0 or .moveSettings.energyDelta == null) |
[
.moveSettings.movementId,
(.templateId | capture("^V[0-9]+_MOVE_(?<name>.+)$").name),
.moveSettings.pokemonType,
.moveSettings.power,
.moveSettings.durationMs,
.moveSettings.energyDelta,
.moveSettings.damageWindowStartMs,
.moveSettings.damageWindowEndMs
]' | sed -E 's/^\[//g' | sed -E 's/\]$//g' > ${FASTMOVE_FILE}




# Chargemove data
# [header]
# move_id,codename,move_type,power,duration,energy,damage_window_start,damage_window_end
CHARGEMOVE_FILE="${OUTPUTDIR}/chargemove.csv"
echo "Chargemove: ${CHARGEMOVE_FILE}"

cat ${LOCALFILE} |
jq -c '.itemTemplates[] | select(.templateId | test("^V[0-9]+_MOVE_")) |
select(.moveSettings.energyDelta < 0 and .moveSettings.energyDelta != null) |
[
.moveSettings.movementId,
(.templateId | capture("^V[0-9]+_MOVE_(?<name>.+)$").name),
.moveSettings.pokemonType,
.moveSettings.power,
.moveSettings.durationMs,
.moveSettings.energyDelta * -1,
.moveSettings.damageWindowStartMs,
.moveSettings.damageWindowEndMs
]' | sed -E 's/^\[//g' | sed -E 's/\]$//g' > ${CHARGEMOVE_FILE}


# Type data
# [header]
# type_id,codename
TYPE_FILE="${OUTPUTDIR}/type.csv"
echo "Type: ${TYPE_FILE}"

cat ${LOCALFILE} |
jq -c '.itemTemplates[] | select(.templateId | test("^POKEMON_TYPE_")) |
[
    .typeEffective.attackType,
    (.templateId | capture("^POKEMON_TYPE_(?<name>.+)$").name)
]' | sed -E 's/^\[//g' | sed -E 's/\]$//g' > ${TYPE_FILE}


# Multiplier data
# [header]
# type_id_offense, type_id_defense, multiplier
MULTIPLIER_FILE="${OUTPUTDIR}/multiplier.csv"
echo "Multiplier: ${MULTIPLIER_FILE}"

cat ${LOCALFILE} |
jq -c '.itemTemplates[] | select(.templateId | test("^POKEMON_TYPE_")) |
.typeEffective.attackType as $id |
.typeEffective.attackScalar | to_entries[] |
[$id, .key+1, .value]' | sed -E 's/^\[//g' | sed -E 's/\]$//g' > ${MULTIPLIER_FILE}
