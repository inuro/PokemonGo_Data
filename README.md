# PokemonGo_Data
Scripts for handling PokemonGO DownloadItemTemplatesResponse.proto

## 1. Grab a GAME_MASTER file from Android
1. Install any filemanager app on your Android device
2. Go to /storage/emulated/0/Android/data/com.nianticporoject.pokemongo/files/remote_config_cache/\*_GAME_MASTER
3. Send the file to your PC/Mac

Latest file(@02/25/2017) is 0000015A62513FDA_GAME_MASTER


## 2. Setup environment
Requirement:
- Node.js ( https://nodejs.org )
- ProtoBuf.js ( https://github.com/dcodeIO/ProtoBuf.js )

## 3. Decode GAME_MASTER file into JSON
```
$ node decode_game_master.js GAME_MASTER/0000015A62513FDA_GAME_MASTER > game_master.json
```

## 4. Extract GAME_MASTER.json into CSV files
```
$ ./extract_game_master.sh game_master.json CSV_OUTPUT
```

