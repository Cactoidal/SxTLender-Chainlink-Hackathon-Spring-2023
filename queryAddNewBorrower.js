const queryId = args[0]
const licenser = args[1]
const borrowerAddress = args[2]

var success = 0


//AddBorrower:

// 1 Accesses the biscuit for the Licenser: BISCUITS.LINKLEND
// 2 Writes to the Licenser's table: LINKLEND.<Licenser>
// 3 Waits, then checks that the new borrower exists

const SxTGetLicenserBiscuit = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": DON_AUTH_BISCUIT, "content-type": "application/json"},
  data : {
    "resourceId": "BISCUITS.LINKLEND",
    "sqlText": "SELECT BISCUIT FROM BISCUITS.LINKLEND WHERE USER = " + licenser + '"'
  }
})


const [SxTGetLicenserBiscuitResponse] = await Promise.all([
  SxTGetLicenserBiscuit,
])



const SxTAddBorrower = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/encrypt/dml`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLicenserBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND." + licenser + '"',
    "sqlText": "INSERT INTO LINKLEND." + licenser + "(ID, IDENTITY) VALUES ('" + borrowerAddress + "', '" + secrets.borrowerIdentity + "')"
  }
})


//Wait for successful node to finish job
await new Promise(resolve => setTimeout(resolve, 5000));


const SxTCheckBorrowerId = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLicenserBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND." + licenser + '"',
    "sqlText": "SELECT " + borrowerAddress + " FROM LINKLEND." + licenser + ';"'
  }
})

const [SxTCheckBorrowerIdResponse] = await Promise.all([
  SxTCheckBorrowerId,
])


if (!SxTCheckBorrowerIdResponse.error) {
  success = 1
} else {
  console.log("SxT error")
}


//return query Id and "1" if successful
return Buffer.concat(
  [
    Functions.encodeUint256(queryId),
    Functions.encodeUint256(success)
  ]
)
