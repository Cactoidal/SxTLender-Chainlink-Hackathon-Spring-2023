# SxTLender
_Lending built using Space and Time and Chainlink Functions._

_________________________________


This project presupposes the existence of the following features:

+ **DON_AUTH_TOKEN:** A Chainlink DON's personal SxT access token. 

+ **BISCUITS Schema:** A SxT schema, controlled by a DON, for tables holding biscuits on behalf of projects that have registered via smart contract.

+ **DON_AUTH_BISCUIT:**  DON-controlled biscuit for accessing the DON-controlled BISCUITS schema.

+ **BISCUITCREATOR:** An API or command enabling the DON to create and store biscuits on behalf of a smart contract, typically to be used in the creation and access of DON-gated tables.

_________________________________

The Chainlink DON will need to have its own SxT Authorization token to process requests; requiring one from all participants as a secret would be prohibitive to the functioning of this project.  The DON will also need to have the ability to create biscuits and create/update tables on behalf of users, while serving as the sole point of access to those tables via the smart contract.

One way of doing this would involve giving contract owners the option of submitting one or multiple PROJECT_SCHEMAs when obtaining a subscriptionId for their Functions Consumer contract.  The DON would then automatically create the PROJECT_SCHEMA(s) on SxT, which the linked contract (and only the linked contract) can access through Functions calls.  

Biscuits associated with the tables of a given PROJECT_SCHEMA would be stored under a universal DON-owned Schema called BISCUITS.  This Schema would store all biscuits for all projects managed by the DON.  

Whenever a new PROJECT_SCHEMA is created, a BISCUITS.PROJECT_SCHEMA table would also be created.  

When a project's smart contract creates a table under their PROJECT_SCHEMA, the Biscuit for that table would be created by the DON and stored on BISCUITS.PROJECT_SCHEMA.  The DON can then later access the project's tables by getting the appropriate biscuit.

_________________________________

## LinkLend
_"Identity is your collateral"_

+ **Licenser:** KYC'd, public, permissioned by LinkLend DAO  (Preferably reliant on DECO)

+ **Borrower:** anonymous on-chain, must prove identity to a Licenser; able to make loan proposals

+ **Lender:** may choose to KYC or remain anonymous; may register and offer loan terms permissionlessly

+ **Collections:** KYC'd, public, permissioned by LinkLend DAO

_________________________________

Introducing "identity collateral" and off-chain collections as a pathway to permissionless lending.

The process begins with a DAO vetting and selecting Licensers it believes are capable of verifying the identities of prospective borrowers.  When a Licenser is added to the contract, a Chainlink DON will create an encrypted SxT table specifically for use by that Licenser, accessible only through the AddBorrower() function.

Licensers could take several forms, but typically would be public organizations with a good track record in identity services.  Their job would involve processing the applications of borrowers, collecting their names, residences, and any other information necessary for the collections process should any default on a loan.  Via AddBorrower(), this personal information is passed as a secret to the Chainlink DON, which records it on the Licenser's table.  Some information would also be recorded on-chain, such as the Borrower's country and on-chain address.

Once a Borrower's secret identity has been linked to an on-chain address, the Borrower may now make loan proposals, requesting a certain number of tokens.  

Providing these tokens could be any one of many Lenders, who can permissionlessly join the platform by paying a small fee to fund their entry into an SxT table.  Lenders may provide information about themselves or can choose to remain entirely anonymous.  However, to receive notification of a borrower's default, a Lender must provide an email address.  This is passed as a secret to the Chainlink DON, which records it on the Lender table.

Lenders may offer terms to any open loan proposal.  They choose the loan APR and the maturity deadline by which the loan must be fully repaid before default.  The requested tokens are transferred to the contract for escrow.  Borrowers may freely choose to accept or ignore the offer.  If the terms aren't accepted, Lenders may cancel their offer to get their tokens back.

If the terms are accepted, the Borrower will immediately receive the escrowed tokens, and will enter into debt with the Lender.  The Borrower may pay back the loan as quickly or as slowly as they wish, so long as they completely pay it off before maturity.

If the Borrower fails to pay back the loan, the Borrower will enter default and Chainlink Automation (or a manual transaction from the Lender) will trigger a Functions call to the Borrower's Licenser's table, obtaining the Borrower's identity information.  This information will be sent in the same call to the email address provided by the Lender, along with a link to proceed to Collections, and the DON's signature hash.

The Collections process will vary by locality and to be truly operational would require integration with the legal system.  Like Licensers, Collections services would be permissioned by the DAO and would most likely be public organizations with a history in debt collection.

The point of failure in this system is the Licenser.  A malicious or incompetent Licenser could upload the wrong on-chain address for a given identity, which could cause someone to be falsely blamed when that address defaults on a loan.  A malicious defaulted Borrower could also attempt to sue the Licenser, claiming that their defaulted address in fact belongs to someone else.  

Therefore a Licenser will need a method of linking an identity to an on-chain address that is trustless, confidential, and verifiable in the event of default.  This is especially true to prevent identity theft, where a person entirely uninvolved with the platform could be blamed for a default.

Impersonation due to stolen private keys is another inherent risk.   Multiple methods of verification could help defeat this and other problems relating to user identity.
