/*
*/
'use strict'

const pg = require('pg')
//var client = new pg.Client("postgres://taro_kawai:@localhost:5432/postgres");


const params = process.argv.slice(2)
if (params.length < 5){
  console.error('usage: cp.js name AT DF HP lv')
  process.exit()
}
else{
  //console.error(params)
}

const condition = {
  "name": params[0]
, "at": parseInt(params[1])
, "df": parseInt(params[2])
, "hp": parseInt(params[3])
, "lv": params[4]
}


var CPM = {}
CPM[1] = 0.09399999678
CPM[1.5] = 0.1351374308
CPM[2] = 0.1663978696
CPM[2.5] = 0.1926509145
CPM[3] = 0.2157324702
CPM[3.5] = 0.236572655
CPM[4] = 0.2557200491
CPM[4.5] = 0.2735303811
CPM[5] = 0.2902498841
CPM[5.5] = 0.3060573813
CPM[6] = 0.3210875988
CPM[6.5] = 0.3354450323
CPM[7] = 0.3492126763
CPM[7.5] = 0.3624577488
CPM[8] = 0.3752355874
CPM[8.5] = 0.3875924111
CPM[9] = 0.3995672762
CPM[9.5] = 0.4111935495
CPM[10] = 0.4225000143
CPM[10.5] = 0.4329264134
CPM[11] = 0.4431075454
CPM[11.5] = 0.4530599539
CPM[12] = 0.4627983868
CPM[12.5] = 0.4723360778
CPM[13] = 0.481684953
CPM[13.5] = 0.4908558103
CPM[14] = 0.499858439
CPM[14.5] = 0.5087017569
CPM[15] = 0.5173939466
CPM[15.5] = 0.5259425088
CPM[16] = 0.5343543291
CPM[16.5] = 0.5426357622
CPM[17] = 0.5507926941
CPM[17.5] = 0.5588305994
CPM[18] = 0.5667545199
CPM[18.5] = 0.574569148
CPM[19] = 0.5822789073
CPM[19.5] = 0.589887912
CPM[20] = 0.5974000096
CPM[20.5] = 0.6048236575
CPM[21] = 0.6121572852
CPM[21.5] = 0.6194041106
CPM[22] = 0.6265671253
CPM[22.5] = 0.6336491816
CPM[23] = 0.6406529546
CPM[23.5] = 0.6475809633
CPM[24] = 0.6544356346
CPM[24.5] = 0.6612192635
CPM[25] = 0.6679340005
CPM[25.5] = 0.6745818993
CPM[26] = 0.6811649203
CPM[26.5] = 0.6876849059
CPM[27] = 0.6941436529
CPM[27.5] = 0.7005428933
CPM[28] = 0.7068842053
CPM[28.5] = 0.7131691023
CPM[29] = 0.7193990946
CPM[29.5] = 0.725575617
CPM[30] = 0.7317000031
CPM[30.5] = 0.7347410111
CPM[31] = 0.7377694845
CPM[31.5] = 0.7407855746
CPM[32] = 0.7437894344
CPM[32.5] = 0.7467812087
CPM[33] = 0.749761045
CPM[33.5] = 0.7527291053
CPM[34] = 0.7556855083
CPM[34.5] = 0.7586303665
CPM[35] = 0.7615638375
CPM[35.5] = 0.7644860653
CPM[36] = 0.7673971653
CPM[36.5] = 0.770297274
CPM[37] = 0.7731865048
CPM[37.5] = 0.7760649459
CPM[38] = 0.7789327502
CPM[38.5] = 0.7817900648
CPM[39] = 0.7846369743
CPM[39.5] = 0.7874735836
CPM[40] = 0.7903000116


var pokemon_id = '';
var baseAT, baseDF, baseHP
var client = new pg.Client({
  user: "taro_kawai",
  database: "postgres"
})

client.connect()
.then(result => {
  // retrieve pokemon_id by name
  return client.query(`select * from pokemon.localize_pokemon where jp='${condition.name}';`)
})
.then(result => {
  // retrieve pokemon base stats
  pokemon_id = result.rows[0].id
  console.error(`pokemon_id:${pokemon_id}`)
  return client.query(`select * from pokemon.pokemon where id='${pokemon_id}';`)
})
.then(result => {
  //console.error(result.rows[0])
  baseAT = result.rows[0].at
  baseDF = result.rows[0].df
  baseHP = result.rows[0].st
  console.error(`ID: ${pokemon_id} / AT: ${baseAT}+${condition.at} / DF: ${baseDF}+${condition.df} / HP: ${baseHP}+${condition.hp}`)

  var cpm = CPM[condition.lv]
  var calculatedHP = Math.floor((baseHP + condition.hp) * cpm)
  var calculatedCP = Math.max(
    10,
    Math.floor(
      (baseAT + condition.at) * Math.pow(baseDF + condition.df, 0.5) * Math.pow(baseHP + condition.hp, 0.5) * Math.pow(cpm, 2) / 10
    )
  )
  console.log(`LV:${condition.lv} CP:${calculatedCP} HP:${calculatedHP}`)
  console.log('---- other levels ----')
  for(var lv=30; lv>=1; lv--){
    var cpm = CPM[lv]
    var calculatedHP = Math.floor((baseHP + condition.hp) * cpm)
    var calculatedCP = Math.max(
      10,
      Math.floor(
        (baseAT + condition.at) * Math.pow(baseDF + condition.df, 0.5) * Math.pow(baseHP + condition.hp, 0.5) * Math.pow(cpm, 2) / 10
      )
    )
    console.log(`LV:${lv} CP:${calculatedCP} HP:${calculatedHP}`)
  }
})
.then(() => {
  client.end()
})
.catch(err => {
  console.error(err)
  client.end()
})
