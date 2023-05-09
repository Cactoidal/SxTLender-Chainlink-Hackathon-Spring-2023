
const queryId = args[0]
const licenser = args[1]


var success = 0

// AddLicenser:

// 1 Creates the biscuit for the Licenser table: sxtcli sql-support table-authz (or access DON biscuit API)
// 2 and adds it to DON biscuits:  BISCUITS.LINKLEND
// 3 Creates the Licenser's table under the project schema:   LINKLEND.<Licenser>
// 4 Waits, then checks if biscuit and table exist


//This is a hypothetical function that would allow the DON to generate biscuits as needed
const SxTBiscuitCreate = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/BISCUITCREATOR`,
  method: "GET",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": DON_AUTH_BISCUIT, "content-type": "application/json"},
  data : {
    "command": "sxtcli sql-support table-authz --accessType=PERMISSIONED --privateKey=" + DON_BISCUIT_PRIVATE_KEY + " --resourceId=LINKLEND." + licenser + '"'
  }
})


const [SxTBiscuitCreateResponse] = await Promise.all([
  SxTBiscuitCreate,
])


const SxTUpdateBiscuitTable = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/encrypt/dml`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": DON_AUTH_BISCUIT, "content-type": "application/json"},
  data : {
    "resourceId": "BISCUITS.LINKLEND",
    "sqlText": "INSERT INTO BISCUITS.LINKLEND (USER, BISCUIT) VALUES ('" + licenser + "', '" + SxTBiscuitCreateResponse.data[0]["BISCUIT"] + "')"
  }
})


//Table will be encrypted at creation
const SxTCreateLicenserTable = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/ddl`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTBiscuitCreateResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "sqlText": "CREATE TABLE LINKLEND." + licenser + "(ID INT, IDENTITY VARCHAR, PRIMARY KEY (ID)) WITH \"public_key=" + DON_BISCUIT_PUBLIC_KEY + ",access_type=public_write\""
  },
})

//Wait for successful node to finish job
await new Promise(resolve => setTimeout(resolve, 5000));


const SxTCheckForBiscuit = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLicenserBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "BISCUITS.LINKLEND",
    "sqlText": "SELECT BISCUIT FROM BISCUIT.LINKLEND WHERE ID = " + licenser + ';"'
  }
})


const [SxTCheckForBiscuitResponse] = await Promise.all([
  SxTCheckForBiscuit
])


if (!SxTCheckForBiscuitResponse.error) {
  success = 1
} else {
  console.log("SxT error")
}


const SxTCheckForTable = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLicenserBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND." + licenser + '"',
    "sqlText": "SELECT * FROM LINKLEND." + licenser + ';"'
  }
})


const [SxTCheckForTableResponse] = await Promise.all([
  SxTCheckForTable
])


if (!SxTCheckForTableResponse.error) {
  if(success === 1) {
    console.log("SxT success")
  }
} else {
  success = 0
  console.log("SxT error")
}



//return query Id and "1" if successful
return Buffer.concat(
  [
    Functions.encodeUint256(queryId),
    Functions.encodeUint256(success)
  ]
)
