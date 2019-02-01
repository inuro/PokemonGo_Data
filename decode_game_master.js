/**
  decode_game_master.js
  Decode PokemonGO GAME_MASTER Protocol Buffers binary file into JSON file

  [usage]
  $ node decode_game_master.js ${original_game_master_file} > ${output_file}
  $ node decode_game_master.js GAME_MASTER/0000015A62513FDA_GAME_MASTER > game_master.json

  [requiremnt]
  - fs
  - protobufjs  https://github.com/dcodeIO/ProtoBuf.js
  - PokemonGO Protobuf message schemas(.proto)
*/

'use strict'

const original_game_master_file = process.argv[2] || "GAME_MASTER/0000015A62513FDA_GAME_MASTER";
console.error(`Parse GAME_MASTER file:${original_game_master_file}`);

const fs = require('fs');
const path = require('path');
const protobuf = require("protobufjs");

//protobuf.load("POGOProtos/Networking/Responses/DownloadItemTemplatesResponse.proto")
protobuf.load({file:"POGOProtos/Networking/Responses/DownloadItemTemplatesResponse.proto", root:path.resolve(".")}, function(err, root) {
  if (err){
    console.log("error");
    console.log(err.message);
    //throw err;
  }else{
    const DownloadItemTemplatesResponse = root.lookup("POGOProtos.Networking.Responses.DownloadItemTemplatesResponse");
    const data = fs.readFileSync(original_game_master_file);
    const buffer = Buffer(data);
  //  console.log(buffer.toString());
    const msg = DownloadItemTemplatesResponse.decode(buffer);
    const obj = msg.toObject();
  //  console.log(JSON.stringify(msg, null, 4))
    console.log(JSON.stringify(obj, null, 4));
  }
});
