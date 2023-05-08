
const queryId = args[0]
const licenser = args[1]
const borrowerAddress = args[2]
const lenderAddress = args[3]
const loanId = args[4]

var success = 0

// ReportDefault:

// 1 Gets the biscuit for the Licenser's table:  BISCUITS.LINKLEND
// 2 Accesses the Licenser's table and gets Borrower info: LINKLEND.<Licenser>
// 3 Gets the biscuit for the Lender table:  BISCUITS.LINKLEND
// 4 Accesses the Lender table for Lender's contact info: LINKLEND.LENDERS
// 5 Emails the Lender

const SxTGetLicenserBiscuit = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": DON_AUTH_BISCUIT, "content-type": "application/json"},
  data : {
    "resourceId": "BISCUITS.LINKLEND",
    "sqlText": "SELECT BISCUIT FROM BISCUITS.LINKLEND WHERE USER = " + licenser + ';"'
  }
})

const [SxTGetLicenserBiscuitResponse] = await Promise.all([
  SxTGetLicenserBiscuit,
])


const SxTGetBorrowerInfo = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/decrypt/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLicenserBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND." + licenser + '"',
    "sqlText": "SELECT IDENTITY FROM LINKLEND." + licenser + " WHERE ID = " + borrowerAddress + ';"'
  }
})


const [SxtGetBorrowerInfoResponse] = await Promise.all([
  SxTGetBorrowerInfo,
])


if (!SxTGetBorrowerInfoResponse.error) {
  success = 1
} else {
  console.log("SxT error")
}


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



const SxTGetLenderInfo = Functions.makeHttpRequest({
  url: `https://hackathon.spaceandtime.dev/v1/sql/dql`,
  method: "POST",
  headers: { "accept": "application/json", "authorization": DON_AUTH_TOKEN , "biscuit": SxTGetLenderBiscuitResponse.data[0]["BISCUIT"], "content-type": "application/json"},
  data : {
    "resourceId": "LINKLEND.LENDERS",
    "sqlText": "SELECT CONTACTAPI, CONTACT FROM LINKLEND.LENDERS WHERE ID = " + lenderAddress + ';"'
  }
})

const [SxTGetLenderInfoResponse] = await Promise.all([
  SxTGetLenderInfo,
])


const LenderContact = Functions.makeHttpRequest({
  url: "`" + SxTGetLenderInfoResponse.data[0]["CONTACTAPI"] + "`",
  method: "POST",
  headers: { "accept": "application/json", "account": SxTGetLenderInfoResponse.data[0]["CONTACT"], "content-type": "application/json"},
  data : {
    "message": "The following borrower has defaulted on position " + loanId + ": " + SxtGetBorrowerInfoResponse.data[0]["IDENTITY"] + ".  Click here to proceed to collections: https://linkcollectors.link",
    "hash": '"' + DONSignature + '"'
  }
})

const [LenderContactResponse] = await Promise.all([
  LenderContact,
])


if (!LenderContactResponse.error) {
  if(success === 1) {
  console.log("SxT success")
  }
} else {
  success = 0
}


//return query Id and "1" if successful
return Buffer.concat(
  [
    Functions.encodeUint256(queryId),
    Functions.encodeUint256(success)
  ]
)
