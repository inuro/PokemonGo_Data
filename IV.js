/*
*/
'use strict'

const pg = require('pg')
//var client = new pg.Client("postgres://taro_kawai:@localhost:5432/postgres");


const params = process.argv.slice(2)
if (params.length < 7){
  console.error('usage: hoge.js name cp hp stardust overall(A,B,C,D) bestAttr(HP,DF,AT,HPDF,HPAT,DFAT,ALL) bestAttrStats(S,A,B,C)')
  process.exit()
}
else{
  //console.error(params)
}

const condition = {
  "name": params[0]
, "cp": params[1]
, "hp": params[2]
, "stardust": params[3]
, "overall": params[4]
, "bestAttr": params[5]
, "bestAttrStats": params[6]
}

// best attributes restriction function definition
var bestAttrFlag = {
  'HP' : false,
  'AT' : false,
  'DF' : false
};
var bestAttrRestriction
switch (condition.bestAttr){
  case 'HP':
    bestAttrFlag.HP = true
    bestAttrRestriction = stats => {
      return stats.HP > stats.AT && stats.HP > stats.DF
    }
    break
  case 'AT':
    bestAttrFlag.AT = true
    bestAttrRestriction = stats => {
      return stats.AT > stats.DF && stats.AT > stats.HP
    }
    break
  case 'DF':
    bestAttrFlag.DF = true
    bestAttrRestriction = stats => {
      return stats.DF > stats.AT && stats.DF > stats.HP
    }
    break
  case 'HPDF':
  case 'DFHP':
    bestAttrFlag.HP = true
    bestAttrFlag.DF = true
    bestAttrRestriction = stats => {
      return stats.HP == stats.DF && stats.HP > stats.AT
    }
    break
  case 'HPAT':
  case 'ATHP':
    bestAttrFlag.HP = true
    bestAttrFlag.AT = true
    bestAttrRestriction = stats => {
      return stats.HP == stats.AT && stats.HP > stats.DF
    }
    break
  case 'ATDF':
  case 'DFAT':
    bestAttrFlag.AT = true
    bestAttrFlag.DF = true
    bestAttrRestriction = stats => {
      return stats.AT == stats.DF && stats.AT > stats.HP
    }
    break
  case 'ALL':
  case 'ATDFHP':
  case 'ATHPDF':
  case 'DFATHP':
  case 'DFHPAT':
  case 'HPATDF':
  case 'HPDFAT':
    bestAttrFlag.HP = true
    bestAttrFlag.AT = true
    bestAttrFlag.DF = true
    bestAttrRestriction = stats => {
      return stats.HP == stats.DF && stats.HP == stats.AT
    }
    break
  default:
    bestAttrRestriction = stats => {
      return false
    }
    break
}
//console.error(`bestAttrRestriction: ${bestAttrRestriction}`)

//overall restriction function definition
var overallRestriction
switch (condition.overall){
  case 'A':
    overallRestriction = stats => {
      return stats.HP + stats.AT + stats.DF >= 37
    }
    break
  case 'B':
    overallRestriction = stats => {
      return stats.HP + stats.AT + stats.DF >= 30 && stats.HP + stats.AT + stats.DF <= 36
    }
    break
  case 'C':
    overallRestriction = stats => {
      return stats.HP + stats.AT + stats.DF >= 23 && stats.HP + stats.AT + stats.DF <= 29
    }
    break
  case 'D':
    overallRestriction = stats => {
      return stats.HP + stats.AT + stats.DF <= 22
    }
    break
  default:
    overallRestriction = stats => {
      return false
    }
}
//console.error(`overallRestriction: ${overallRestriction}`)


//bestAttrStats restriction definition
var bestAttrStatsMin = 0, bestAttrStatsMax = 15
switch(condition.bestAttrStats){
  case 'C':
    bestAttrStatsMin = 0
    bestAttrStatsMax = 7
    break
  case 'B':
    bestAttrStatsMin = 8
    bestAttrStatsMax = 12
    break
  case 'A':
    bestAttrStatsMin = 13
    bestAttrStatsMax = 14
    break
  case 'S':
    bestAttrStatsMin = 15
    bestAttrStatsMax = 15
    break
}
//console.error(`bestStats: ${bestAttrStatsMin} - ${bestAttrStatsMax}`)

// available level range
var availableLV
switch(condition.stardust){
  case '200':
    availableLV = [1, 1.5, 2, 2.5]
    break
  case '400':
    availableLV = [3, 3.5, 4, 4.5]
    break
  case '600':
    availableLV = [5, 5.5, 6, 6.5]
    break
  case '800':
    availableLV = [7, 7.5, 8, 8.5]
    break
  case '1000':
    availableLV = [9, 9.5, 10, 10.5]
    break
  case '1300':
    availableLV = [11, 11.5, 12, 12.5]
    break
  case '1600':
    availableLV = [13, 13.5, 14, 14.5]
    break
  case '1900':
    availableLV = [15, 15.5, 16, 16.5]
    break
  case '2200':
    availableLV = [17, 17.5, 18, 18.5]
    break
  case '2500':
    availableLV = [19, 19.5, 20, 20.5]
    break
  case '3000':
    availableLV = [21, 21.5, 22, 22.5]
    break
  case '3500':
    availableLV = [23, 23.5, 24, 24.5]
    break
  case '4000':
    availableLV = [25, 25.5, 26, 26.5]
    break
  case '4500':
    availableLV = [27, 27.5, 28, 28.5]
    break
  case '5000':
    availableLV = [29, 29.5, 30, 30.5]
    break
  case '6000':
    availableLV = [31, 31.5, 32, 32.5]
    break
  case '7000':
    availableLV = [33, 33.5, 34, 34.5]
    break
  case '8000':
    availableLV = [35, 35.5, 36, 36.5]
    break
  case '9000':
    availableLV = [37, 37.5, 38, 38.5]
    break
  case '10000':
    availableLV = [39, 39.5, 40]
    break
  default:
    availableLV = []
    break
}
//console.error(`availableLV: ${availableLV}`)


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
  //console.error(`ID: ${pokemon_id} / AT: ${baseAT} / DF: ${baseDF} / HP: ${baseHP}`)
})
.then(() => {
  // At first, guess HP
  // HP = (Base HP + Individual HP) * CP_Multiplier
  var availableLVandHP = []
  var min = 0, max = 15
  if(bestAttrFlag.HP){
    min = bestAttrStatsMin
    max = bestAttrStatsMax
  }
  //console.error(`user input hp: ${condition.hp}`)
  for(let i = 0; i < availableLV.length; i++){
    var lv = availableLV[i]
    var cpm = CPM[lv]
    //console.error(`test level:${lv} cpm:${cpm}`)

    //traverse from min <= HPIV < max
    for(let IVHP = min; IVHP <= max; IVHP++){
      var calculatedHP = Math.floor((baseHP + IVHP) * cpm)
      //console.error(`caluculated hp: ${calculatedHP}`)
      if(calculatedHP == condition.hp){
        availableLVandHP.push({
          'LV': lv,
          'HP': IVHP
        })
        console.error(`HP matched: LV:${lv} IVHP:${IVHP}`)
      }
    }
  }
  return availableLVandHP
})
.then(availableLVandHP => {
  // Guess AT and DF
  // CP = (Attack * Defense^0.5 * HP^0.5 * CP_Multiplier^2) / 10
  var availableStats = [];

  //traverse available LV&HP
  for(let i = 0; i < availableLVandHP.length; i++){
    var lv = availableLVandHP[i].LV
    var IVHP = availableLVandHP[i].HP
    var cpm = CPM[lv]

    //traverse available AT & DF
    var ATmin = 0, ATmax = 15
    if(bestAttrFlag.AT){
      ATmin = bestAttrStatsMin
      ATmax = bestAttrStatsMax
    }
    var DFmin = 0, DFmax = 15
    if(bestAttrFlag.DF){
      DFmin = bestAttrStatsMin
      DFmax = bestAttrStatsMax
    }
    for(let IVAT = ATmin; IVAT <= ATmax; IVAT++){
      for(let IVDF = DFmin; IVDF <= DFmax; IVDF++){
        var calculatedCP = Math.max(10, Math.floor((baseAT + IVAT) * Math.pow(baseDF + IVDF, 0.5) * Math.pow(baseHP + IVHP, 0.5) * Math.pow(cpm, 2) / 10))
      //  console.error(`CP:${calculatedCP} LV:${lv} AT:${IVAT} DF:${IVDF} HP:${IVHP}`)
        if(calculatedCP == condition.cp){
          var stats = {
            'LV': lv,
            'AT': IVAT,
            'DF': IVDF,
            'HP': IVHP
          }
          if(bestAttrRestriction(stats) && overallRestriction(stats)){
            availableStats.push(stats)
            console.error(`AT/DF matched LV:${lv} AT:${IVAT} DF:${IVDF} HP:${IVHP}`)
          }
        }
      }
    }
  }
  return availableStats
})
.then(availableStats => {
  availableStats.forEach((item, index) => {
    console.log('--------')
    var IV = Math.floor((item.AT + item.DF + item.HP) / 45 * 100)
    console.log(`LV:${item.LV} - AT:${item.AT} DF:${item.DF} HP:${item.HP} (${IV}%)`)

    var LV30CP = Math.max(10, Math.floor((baseAT + item.AT) * Math.pow(baseDF + item.DF, 0.5) * Math.pow(baseHP + item.HP, 0.5) * Math.pow(CPM[30], 2) / 10))
    console.log(`LV:30 - CP:${LV30CP}`)
    var LV39CP = Math.max(10, Math.floor((baseAT + item.AT) * Math.pow(baseDF + item.DF, 0.5) * Math.pow(baseHP + item.HP, 0.5) * Math.pow(CPM[39], 2) / 10))
    console.log(`LV:39 - CP:${LV39CP}`)
  })
})
.then(() => {
  client.end()
})
.catch(err => {
  //console.error(err)
  client.end()
})







/*
//retrieve pokemon id from name
var pokemon_id;
var client1 = new pg.Client({
  user: "taro_kawai",
  database: "postgres"
})
client1.connect(function(err){
  client1.query(`select * from pokemon.localize_pokemon where jp='${condition.name}';`)
  .then(result => {
    //console.error(result.rows[0])
    pokemon_id = result.rows[0].id
    console.error(`pokemon_id:${pokemon_id}`)
  })
  .catch(e => {
    console.error(`couldn't find Pokemon "${condition.name}"`)
    client1.end()
    process.exit()
  })
  .then(() => {
    client1.query(`select * from pokemon.pokemon where id='${pokemon_id}';`)
    .then(result => {
      console.log(result.rows[0])
    })
  })
})
*/





/*
var client = new pg.Client({
  user: "taro_kawai",
  database: "postgres"
})
client.connect()

const getPokemonId = new Promise((resolve, reject) => {
  client.query(`select * from pokemon.localize_pokemon where jp='${condition.name}';`)
  .then(result => {
    const pokemon_id = result.rows[0].id
    resolve(pokemon_id)
  })
  .catch(e => {
    reject()
  })
})
Promise.all([getPokemonId])
.then(res => {
  console.error(`pokemon_id:${res}`)
}, err => {
  console.error(`couldn't find Pokemon "${condition.name}"`)
})
.then(()=> client.end())
*/










/*
// retrieve pokemon base stats
var client2 = new pg.Client({
  user: "taro_kawai",
  database: "postgres"
})
client2.connect();
client2.query(`select * from pokemon.pokemon where id='${pokemon_id}';`)
.then(function(result){
    console.log(result.rows[0]);
})
.then(function(){
  client2.end()
})

*/
