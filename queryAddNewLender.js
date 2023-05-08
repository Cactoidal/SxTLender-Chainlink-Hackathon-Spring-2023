
const queryId = args[0]
const lenderAddress = args[1]

var success = 0

// AddLender:

// 1 Accesses the biscuit for the Lender table: BISCUITS.LINKLEND
// 2 Writes to the Lender table: LINKLEND.LENDERS
// 3 Waits, then confirms new lender exists


const SxTGetLenderBiscuit = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": DON_AUTH_BISCUIT, "content-type": "application/json"},
  data : {
    "resourceId": "BISCUITS.LINKLEND",
    "sqlText": "SELECT BISCUIT FROM BISCUITS.LINKLEND WHERE USER = LENDERS;"
  }
})


const [SxTGetLenderBiscuitResponse] = await Promise.all([
  SxTGetLenderBiscuit,
])


const SxTAddLender = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/encrypt/dml`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLenderBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND.LENDERS",
    "sqlText": "INSERT INTO LINKLEND.LENDERS (ID, CONTACTAPI, CONTACT) VALUES ('" + lenderAddress + "', '" + secrets.CONTACTAPI + "', " + secrets.CONTACT + '")"'
  }
})



//Wait for successful node to finish job
await new Promise(resolve => setTimeout(resolve, 5000));



const SxTCheckLenderId = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLenderBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND.LENDERS",
    "sqlText": "SELECT " + lenderAddress + " FROM LINKLEND.LENDERS;"
  }
})

const [SxTCheckLenderIdResponse] = await Promise.all([
  SxTCheckLenderId,
])


if (!SxTCheckLenderIdResponse.error) {
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
