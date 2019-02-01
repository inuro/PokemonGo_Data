/*
*/
'use strict'

const pg = require('pg')
//var client = new pg.Client("postgres://taro_kawai:@localhost:5432/postgres");

//sql
const fs = require('fs')

const params = process.argv.slice(2)
if (params.length < 1){
  console.error('usage: what_moves.js pokemon_name_jp')
  process.exit()
}
else{
  //console.error(params)
}
const condition = {
  "name": params[0],
  "table_name": "dammy"
}

const query = `
drop table if exists ${condition.table_name};
create table ${condition.table_name} (id integer, ${condition.name} text);
`
const query3 = `
select * from ${condition.table_name};
`


console.log("query:", query)

var client = new pg.Client({
  user: "taro_kawai",
  database: "postgres"
})

client.connect()
.then(result => {
  return client.query(query)
})
.then(result => {
  console.log("result:")
  console.log(result)

  for(var i=0; i<2; i++){
    const query2 = `insert into ${condition.table_name}(id, ${condition.name}) values(${i},'${"hogehoge"+i}');`
    client.query(query2)
  }
})
.then(result => {
  console.log("result2:")
  console.log(result)
  return client.query(query3)
})
.then(result => {
  console.log("result3:")
  console.log(result)
})
.then(() => {
  client.end()
})
.catch(err => {
  console.log("error:")
  console.error(err)
  client.end()
})
