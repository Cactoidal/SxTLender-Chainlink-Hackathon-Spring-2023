// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./contracts/dev/functions/Functions.sol";
import "./contracts/dev/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract Lender is FunctionsClient, ConfirmedOwner {
  using Functions for Functions.Request;

  constructor(address oracle, address linkToken, address feeAddress, string memory _addLicenserSxT, string memory _addBorrowerSxT, string memory _registerLenderSxT, string memory _reportDefaultSxT, string memory _createLenderTableSxT) FunctionsClient(oracle) ConfirmedOwner(msg.sender) {

  CHAINLINK_TOKEN_ADDRESS = linkToken;
  DAO_FEE_ADDRESS = feeAddress;
  addLicenserSxT = _addLicenserSxT;
  addBorrowerSxT = _addBorrowerSxT;
  registerLenderSxT = _registerLenderSxT;
  reportDefaultSxT = _reportDefaultSxT;
  createLenderTableSxT = _createLenderTableSxT;

  }

  bytes32 public latestRequestId;
  bytes public latestResponse;
  bytes public latestError;
  address public CHAINLINK_TOKEN_ADDRESS;
  address public DAO_FEE_ADDRESS;

  event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);
  
 
  struct licenserInfo {
    string name;
    string url;
    string location;
    address onChainAddress;
    uint borrowers;
    bool activated;
  }

  //Do not propose loans of tax-on-transfer tokens
  struct loanProposal {
    address token;
    uint amount;
    uint proposalId;
    string reason;
    uint APR;
    uint maturity;
    uint debtBalance;
    uint paidBalance;
    uint startTime;
    uint lastPaymentTime;
    string status;
    address lenderAddress;
  }

  struct onChainBorrowerInfo {
    string licenser;
    uint borrowerId;
    address onChainAddress;
    string country;
    loanProposal[] Proposals;
    string delinquencyStatus;
  }

  struct lenderInfo {
    string name;
    string url;
    string location;
    address onChainAddress;
    uint lenderId;
    bool registered;
  }

  struct loanTerms {
    uint lenderId;
    address lenderAddress;
    address token;
    uint amount;
    uint APR;
    uint maturity;
    string status;
  }

  struct pendingSxT {
    bool pending;
    bool success;
    uint queryType;
    uint startTime;
    string licenser;
    uint borrowerId;
    onChainBorrowerInfo pendingInfo;
    lenderInfo pendingLender;
    uint proposalIndex;
  }

  uint public lenderId = 1;

  uint public proposalId = 1;

  mapping (string => licenserInfo) public approvedLicensers;

  mapping (string => mapping (uint => onChainBorrowerInfo)) public licensedBorrowers;

  mapping (string => mapping (address => uint)) public borrowerIdReference;

  mapping (address => lenderInfo) public lenderRegistry;

  mapping (uint => loanTerms[]) public loanTermsByProposalId;

  string public addLicenserSxT;

  string public addBorrowerSxT;

  string public registerLenderSxT;

  string public reportDefaultSxT;

  string public createLenderTableSxT;

  uint public queryId = 1;

  mapping (uint => pendingSxT) public queries;

  mapping (address => uint) public userLastQuery;

  bool public instantiatedLenderTable;

  //The DAO grants permission for a Licenser to join, and creates the Licenser's table with
  //a Functions call.
  function beginAddLicenser(string memory _name, string memory _url, string memory _location, address controller) public onlyOwner {
    checkQuery(1);
    licenserInfo memory newLicenser;
    newLicenser.name = _name;
    newLicenser.url = _url;
    newLicenser.location = _location;
    newLicenser.onChainAddress = controller;
    newLicenser.borrowers = 1;
    approvedLicensers[_name] = newLicenser;

    queries[userLastQuery[msg.sender]].licenser = _name;

    executeRequest(addLicenserSxT, "", [Strings.toString(queryId), _name, "nil", "nil", "nil", "nil"], 77, 300000);
  }

  function fulfillAddLicenser(uint _queryId) internal {
    approvedLicensers[queries[_queryId].licenser].activated = true;
  }



  //addBorrower is done via Functions, with the licenser sending the Borrower info as a secret.
  function beginAddBorrower(string memory _licenser, address borrowerAddress, string memory _country, bytes memory secrets) public {
    require(msg.sender == approvedLicensers[_licenser].onChainAddress);
    require(approvedLicensers[_licenser].activated == true);
    checkQuery(2);
    onChainBorrowerInfo memory newBorrower;
    newBorrower.licenser = _licenser;
    newBorrower.borrowerId = approvedLicensers[_licenser].borrowers;
    newBorrower.onChainAddress = borrowerAddress;
    newBorrower.country = _country;
    newBorrower.delinquencyStatus = "None";
    queries[userLastQuery[msg.sender]].pendingInfo = newBorrower;
    queries[userLastQuery[msg.sender]].licenser = _licenser;

    executeRequest(addBorrowerSxT, secrets, [Strings.toString(queryId), _licenser, Strings.toHexString(borrowerAddress), "nil", "nil", "nil"], 77, 300000);
  }

  function fulfillAddBorrower(uint _queryId) internal {
    licensedBorrowers[queries[_queryId].licenser][approvedLicensers[queries[_queryId].licenser].borrowers] = queries[queryId].pendingInfo;
    borrowerIdReference[queries[_queryId].licenser][queries[_queryId].pendingInfo.onChainAddress] = approvedLicensers[queries[_queryId].licenser].borrowers;
    approvedLicensers[queries[_queryId].licenser].borrowers++;
  }


  function getLicenserBorrowers(string memory licenser) public view returns (onChainBorrowerInfo[] memory borrowerList) {
    borrowerList = new onChainBorrowerInfo[](approvedLicensers[licenser].borrowers - 1);
    for (uint i = 1; i < approvedLicensers[licenser].borrowers; i++) {
        borrowerList[i-1] = (licensedBorrowers[licenser][i]);
    }
    return borrowerList;
  }

  function beginCreateLenderTable() public onlyOwner {
    require(instantiatedLenderTable == false);
    checkQuery(3);
    executeRequest(createLenderTableSxT, "", [Strings.toString(queryId), "nil", "nil", "nil", "nil", "nil"], 77, 300000);
  }

  function fulfillCreateLenderTable() public onlyOwner {
    instantiatedLenderTable = true;
  }

  //Providing personal information is optional at the discretion of the lender.
  //Email is necessary to receive borrower identity information in case of default.
  //This email needs to be confidential, therefore the user uploads it to SxT
  //by passing it as a secret.

  //Small registration fee to discourage spam and fund Functions subscription
  function beginRegisterLender(string memory _name, string memory _url, string memory _location, address lenderAddress, bytes memory secrets) public {
    require (instantiatedLenderTable == true);
    require (lenderRegistry[msg.sender].registered == false);
    require (IERC20(CHAINLINK_TOKEN_ADDRESS).balanceOf(msg.sender) >= (1*1e18));

    checkQuery(4);

    lenderInfo memory newLender;
    newLender.name = _name;
    newLender.url = _url;
    newLender.location = _location;
    newLender.onChainAddress = lenderAddress;

    queries[userLastQuery[msg.sender]].pendingLender = newLender;
  
    executeRequest(registerLenderSxT, secrets, [Strings.toString(queryId), Strings.toHexString(lenderAddress), "nil", "nil", "nil", "nil"], 77, 300000);
    IERC20(CHAINLINK_TOKEN_ADDRESS).transferFrom(msg.sender, DAO_FEE_ADDRESS, (1*1e18));
  }

  function fulfillRegisterLender(uint _queryId) internal {
    queries[_queryId].pendingLender.lenderId = lenderId;
    queries[_queryId].pendingLender.registered = true;
    lenderRegistry[queries[_queryId].pendingLender.onChainAddress] = queries[_queryId].pendingLender;
    lenderId++;
  }




  function proposeLoan(string memory licenser, address _token, uint _amount, string memory _reason) public {
    require(msg.sender == licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].onChainAddress);
    loanProposal memory newProposal;
    newProposal.token = _token;
    newProposal.amount = _amount;
    newProposal.reason = _reason;
    newProposal.status = "Open";
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals.push(newProposal);
  }

  function cancelProposal(string memory licenser, uint proposalIndex) public {
    require(msg.sender == licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].onChainAddress);
    require(keccak256(abi.encodePacked(licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].status)) == keccak256(abi.encodePacked("Open")));
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].status = "Cancelled";
  }


  function offerTerms(string memory licenser, uint borrowerId, uint proposalIndex, uint _APR, uint _maturity) public {
    require(lenderRegistry[msg.sender].registered == true);
    require(keccak256(abi.encodePacked(licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].status)) == keccak256(abi.encodePacked("Open")));
    require(IERC20(licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].token).balanceOf(msg.sender) >= licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].amount);
    loanTerms memory newTerms;
    newTerms.lenderId = lenderRegistry[msg.sender].lenderId;
    newTerms.amount = licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].amount;
    newTerms.token = licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].token;
    newTerms.APR = _APR;
    newTerms.maturity = _maturity;
    newTerms.lenderAddress = msg.sender;
    newTerms.status = "Offered";
    loanTermsByProposalId[licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].proposalId].push(newTerms);
    IERC20(licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].token).transferFrom(msg.sender, address(this), licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].amount);
  }

  

  function cancelOffer(uint _proposalId, uint termsIndex) public {
    require(keccak256(abi.encodePacked(loanTermsByProposalId[_proposalId][termsIndex].status)) == keccak256(abi.encodePacked("Offered")));
    require(msg.sender == loanTermsByProposalId[_proposalId][termsIndex].lenderAddress);
    loanTermsByProposalId[proposalId][termsIndex].status = "Cancelled";
    IERC20(loanTermsByProposalId[_proposalId][termsIndex].token).transferFrom(address(this), msg.sender, loanTermsByProposalId[_proposalId][termsIndex].amount);
  }

  function acceptTerms(string memory licenser, uint proposalIndex, uint termsIndex) public {
    require(msg.sender == licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].onChainAddress);
    require(keccak256(abi.encodePacked(licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].status)) == keccak256(abi.encodePacked("Open")));
    require(keccak256(abi.encodePacked(loanTermsByProposalId[proposalIndex][termsIndex].status)) == keccak256(abi.encodePacked("Offered")));
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].status = "Active";
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].APR = loanTermsByProposalId[proposalIndex][termsIndex].APR;
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].maturity = loanTermsByProposalId[proposalIndex][termsIndex].maturity;
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].debtBalance = licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].amount;
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].lenderAddress = loanTermsByProposalId[proposalIndex][termsIndex].lenderAddress;
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].startTime = block.timestamp;
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].lastPaymentTime = block.timestamp;
    loanTermsByProposalId[proposalIndex][termsIndex].status = "Accepted";
    IERC20(licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].token).transferFrom(address(this), msg.sender, licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].amount);
  }

  function makePayment(string memory licenser, uint proposalIndex, uint _amount) public {
    require(msg.sender == licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].onChainAddress);
    require(keccak256(abi.encodePacked(licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].status)) == keccak256(abi.encodePacked("Active")));
    require(IERC20(licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].token).balanceOf(msg.sender) >= _amount);
    require(_amount <= calculateDebt(licenser, borrowerIdReference[licenser][msg.sender], proposalIndex));
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].debtBalance = calculateDebt(licenser, borrowerIdReference[licenser][msg.sender], proposalIndex);
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].lastPaymentTime = block.timestamp;
    licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].paidBalance += _amount;
    if (licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].paidBalance >= licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].debtBalance) {
      licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].status = "Closed";
    }
    IERC20(licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].token).transferFrom(msg.sender, licensedBorrowers[licenser][borrowerIdReference[licenser][msg.sender]].Proposals[proposalIndex].lenderAddress, _amount);
  }


  function calculateDebt(string memory licenser, uint borrowerId, uint proposalIndex) public view returns (uint) {
    uint pendingDebt = licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].debtBalance - licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].paidBalance;
    uint timeElapsed = block.timestamp - licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].lastPaymentTime;
    pendingDebt += (pendingDebt * (licensedBorrowers[licenser][borrowerId].Proposals[proposalIndex].APR * timeElapsed));
    return pendingDebt;
  }

  //May be configured to be triggered by a Keeper
  function beginReportDefault(string memory _licenser, uint _borrowerId, string memory _lenderId, uint proposalIndex) public {
    require(block.timestamp > licensedBorrowers[_licenser][_borrowerId].Proposals[proposalIndex].startTime + licensedBorrowers[_licenser][_borrowerId].Proposals[proposalIndex].maturity);
    require(keccak256(abi.encodePacked(licensedBorrowers[_licenser][_borrowerId].Proposals[proposalIndex].status)) == keccak256(abi.encodePacked("Active")));
    checkQuery(5);

    queries[userLastQuery[msg.sender]].licenser = _licenser;
    queries[userLastQuery[msg.sender]].borrowerId = _borrowerId;
  
    executeRequest(reportDefaultSxT, "", [Strings.toString(queryId), _licenser, Strings.toHexString(licensedBorrowers[_licenser][_borrowerId].onChainAddress), Strings.toHexString(licensedBorrowers[_licenser][_borrowerId].Proposals[proposalIndex].lenderAddress), Strings.toString(licensedBorrowers[_licenser][_borrowerId].Proposals[proposalIndex].proposalId), "nil"], 77, 300000);
  }

  function fulfillReportDefault(uint _queryId) internal {
    licensedBorrowers[queries[_queryId].licenser][queries[_queryId].borrowerId].Proposals[queries[_queryId].proposalIndex].status = "Default";
    licensedBorrowers[queries[_queryId].licenser][queries[_queryId].borrowerId].delinquencyStatus = "Default";
  }



  //Queries enter a pool while pending and are deactivated when complete.  An address cannot send
  //another query until its pending query has finished. Rescue stuck queries with unstickQuery()
  function checkQuery(uint _queryType) internal {
    require(queries[userLastQuery[msg.sender]].pending == false);
    userLastQuery[msg.sender] = queryId;
    queries[userLastQuery[msg.sender]].pending = true;
    queries[userLastQuery[msg.sender]].startTime = block.timestamp;
    queries[userLastQuery[msg.sender]].queryType = _queryType;
    queryId++;
  }



  function executeRequest(
    string memory source,
    bytes memory secrets,
    string[6] memory args,
    uint64 subscriptionId,
    uint32 gasLimit
  ) internal returns (bytes32) {

    Functions.Request memory req;
    req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
    if (secrets.length > 0) {
      req.addRemoteSecrets(secrets);
    }
    if (args.length > 0) req.addArgs(args);

    bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
    latestRequestId = assignedReqID;
    return assignedReqID;
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    latestResponse = response;
    latestError = err;
    uint incomingQueryId;
    uint incomingSuccess;
    (incomingQueryId, incomingSuccess) = abi.decode(response, (uint, uint));

    if(incomingSuccess == 1) {
      queries[incomingQueryId].success = true;
      if(queries[incomingQueryId].queryType == 1) {
        fulfillAddLicenser(incomingQueryId);
      }
      if(queries[incomingQueryId].queryType == 2) {
        fulfillAddBorrower(incomingQueryId);
      }
      if(queries[incomingQueryId].queryType == 3) {
        fulfillCreateLenderTable();
      }
      if(queries[incomingQueryId].queryType == 4) {
        fulfillRegisterLender(incomingQueryId);
      }
      if(queries[incomingQueryId].queryType == 5) {
        fulfillReportDefault(incomingQueryId);
      }
    
    queries[incomingQueryId].pending = false;
      
    }

    emit OCRResponse(requestId, response, err);
  }

  function unstickQuery() public {
    require(queries[userLastQuery[msg.sender]].pending == true);
    require(block.timestamp > (queries[userLastQuery[msg.sender]].startTime + 900));
    queries[userLastQuery[msg.sender]].pending = false;
  }

}
