======> FungibleToken.cdc
/**

# The Flow Fungible Token standard

## `FungibleToken` contract interface

The interface that all fungible token contracts would have to conform to.
If a users wants to deploy a new token contract, their contract
would need to implement the FungibleToken interface.

Their contract would have to follow all the rules and naming
that the interface specifies.

## `Vault` resource

Each account that owns tokens would need to have an instance
of the Vault resource stored in their account storage.

The Vault resource has methods that the owner and other users can call.

## `Provider`, `Receiver`, and `Balance` resource interfaces

These interfaces declare pre-conditions and post-conditions that restrict
the execution of the functions in the Vault.

They are separate because it gives the user the ability to share
a reference to their Vault that only exposes the fields functions
in one or more of the interfaces.

It also gives users the ability to make custom resources that implement
these interfaces to do various things with the tokens.
For example, a faucet can be implemented by conforming
to the Provider interface.

By using resources and interfaces, users of FungibleToken contracts
can send and receive tokens peer-to-peer, without having to interact
with a central ledger smart contract. To send tokens to another user,
a user would simply withdraw the tokens from their Vault, then call
the deposit function on another user's Vault to complete the transfer.

*/

/// FungibleToken
///
/// The interface that fungible token contracts implement.
///
pub contract interface FungibleToken {

    /// The total number of tokens in existence.
    /// It is up to the implementer to ensure that the total supply
    /// stays accurate and up to date
    ///
    pub var totalSupply: UFix64

    /// TokensInitialized
    ///
    /// The event that is emitted when the contract is created
    ///
    pub event TokensInitialized(initialSupply: UFix64)

    /// TokensWithdrawn
    ///
    /// The event that is emitted when tokens are withdrawn from a Vault
    ///
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// TokensDeposited
    ///
    /// The event that is emitted when tokens are deposited into a Vault
    ///
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// Provider
    ///
    /// The interface that enforces the requirements for withdrawing
    /// tokens from the implementing type.
    ///
    /// It does not enforce requirements on `balance` here,
    /// because it leaves open the possibility of creating custom providers
    /// that do not necessarily need their own balance.
    ///
    pub resource interface Provider {

        /// withdraw subtracts tokens from the owner's Vault
        /// and returns a Vault with the removed tokens.
        ///
        /// The function's access level is public, but this is not a problem
        /// because only the owner storing the resource in their account
        /// can initially call this function.
        ///
        /// The owner may grant other accounts access by creating a private
        /// capability that allows specific other users to access
        /// the provider resource through a reference.
        ///
        /// The owner may also grant all accounts access by creating a public
        /// capability that allows all users to access the provider
        /// resource through a reference.
        ///
        pub fun withdraw(amount: UFix64): @Vault {
            post {
                // `result` refers to the return value
                result.balance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
            }
        }
    }

    /// Receiver
    ///
    /// The interface that enforces the requirements for depositing
    /// tokens into the implementing type.
    ///
    /// We do not include a condition that checks the balance because
    /// we want to give users the ability to make custom receivers that
    /// can do custom things with the tokens, like split them up and
    /// send them to different places.
    ///
    pub resource interface Receiver {

        /// deposit takes a Vault and deposits it into the implementing resource type
        ///
        pub fun deposit(from: @Vault)
    }

    /// Balance
    ///
    /// The interface that contains the `balance` field of the Vault
    /// and enforces that when new Vaults are created, the balance
    /// is initialized correctly.
    ///
    pub resource interface Balance {

        /// The total balance of a vault
        ///
        pub var balance: UFix64

        init(balance: UFix64) {
            post {
                self.balance == balance:
                    "Balance must be initialized to the initial balance"
            }
        }
    }

    /// Vault
    ///
    /// The resource that contains the functions to send and receive tokens.
    ///
    pub resource Vault: Provider, Receiver, Balance {

        // The declaration of a concrete type in a contract interface means that
        // every Fungible Token contract that implements the FungibleToken interface
        // must define a concrete `Vault` resource that conforms to the `Provider`, `Receiver`,
        // and `Balance` interfaces, and declares their required fields and functions

        /// The total balance of the vault
        ///
        pub var balance: UFix64

        // The conforming type must declare an initializer
        // that allows prioviding the initial balance of the Vault
        //
        init(balance: UFix64)

        /// withdraw subtracts `amount` from the Vault's balance
        /// and returns a new Vault with the subtracted balance
        ///
        pub fun withdraw(amount: UFix64): @Vault {
            pre {
                self.balance >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the Vault"
            }
            post {
                // use the special function `before` to get the value of the `balance` field
                // at the beginning of the function execution
                //
                self.balance == before(self.balance) - amount:
                    "New Vault balance must be the difference of the previous balance and the withdrawn Vault"
            }
        }

        /// deposit takes a Vault and adds its balance to the balance of this Vault
        ///
        pub fun deposit(from: @Vault) {
            // Assert that the concrete type of the deposited vault is the same
            // as the vault that is accepting the deposit
            pre {
                from.isInstance(self.getType()): 
                    "Cannot deposit an incompatible token type"
            }
            post {
                self.balance == before(self.balance) + before(from.balance):
                    "New Vault balance must be the sum of the previous balance and the deposited Vault"
            }
        }
    }

    /// createEmptyVault allows any user to create a new Vault that has a zero balance
    ///
    pub fun createEmptyVault(): @Vault {
        post {
            result.balance == 0.0: "The newly created Vault must have zero balance"
        }
    }
}



==========> FlowToken.cdc

import FungibleToken from 0x01

pub contract FlowToken: FungibleToken {

    // Total supply of Flow tokens in existence
    pub var totalSupply: UFix64

    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    // Event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    // Event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    // Event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    // Event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in FungibleToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        // holds the balance of a users tokens
        pub var balance: UFix64

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @FlowToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            FlowToken.totalSupply = FlowToken.totalSupply - self.balance
        }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @FungibleToken.Vault {
        return <-create Vault(balance: 0.0)
    }

    pub resource Administrator {
        // createNewMinter
        //
        // Function that creates and returns a new minter resource
        //
        pub fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }

        // createNewBurner
        //
        // Function that creates and returns a new burner resource
        //
        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }
    }

    // Minter
    //
    // Resource object that token admin accounts can hold to mint new tokens.
    //
    pub resource Minter {

        // the amount of tokens that the minter is allowed to mint
        pub var allowedAmount: UFix64

        // mintTokens
        //
        // Function that mints new tokens, adds them to the total supply,
        // and returns them to the calling context.
        //
        pub fun mintTokens(amount: UFix64): @FlowToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            FlowToken.totalSupply = FlowToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    // Burner
    //
    // Resource object that token admin accounts can hold to burn tokens.
    //
    pub resource Burner {

        // burnTokens
        //
        // Function that destroys a Vault instance, effectively burning the tokens.
        //
        // Note: the burned tokens are automatically subtracted from the
        // total supply in the Vault destructor.
        //
        pub fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @FlowToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        self.totalSupply = 0.0

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: /storage/flowTokenVault)

        // Create a public capability to the stored Vault that only exposes
        // the `deposit` method through the `Receiver` interface
        //
        self.account.link<&FlowToken.Vault{FungibleToken.Receiver}>(
            /public/flowTokenReceiver,
            target: /storage/flowTokenVault
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field through the `Balance` interface
        //
        self.account.link<&FlowToken.Vault{FungibleToken.Balance}>(
            /public/flowTokenBalance,
            target: /storage/flowTokenVault
        )

        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/flowTokenAdmin)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}


=====> EducationFund
import FungibleToken from 0x01
import FlowToken from 0x02


pub contract EducationFund {

    // Public resource interface to allow everyone to send Flow tokens to the fund and allows for balance checks.
    pub resource interface PublicFund {
       pub fun checkBalance(): UFix64
       pub fun depositToFund(deposit: @FungibleToken.Vault)
    }

    // main part of the EducationFund
    pub resource Fund: PublicFund {
        pub let ownerVault: @FungibleToken.Vault
        pub var withdrawalLimit: UFix64


        init (vault: @FungibleToken.Vault, limit: UFix64) {
            self.ownerVault <- vault
            self.withdrawalLimit = limit
        }

        pub fun checkBalance(): UFix64 {
            return self.ownerVault.balance
        }

        pub fun depositToFund(deposit: @FungibleToken.Vault) {
            self.ownerVault.deposit(from: <- deposit)
        }

        pub fun increaseWithdrawalLimit(newLimit: UFix64) {
            pre {
                self.withdrawalLimit < newLimit: "You cannot decrease the withdrawal limit"
            }
            self.withdrawalLimit = self.withdrawalLimit + newLimit
        }


        //Have to create a Vault so I can squeeze in the update of the withdrawalLimit before returning the vault. 
        //Looks terrible, but have no idea how to do it in a more proper way
        pub fun withdrawFromFund(request: UFix64):@FungibleToken.Vault {
            var Vault <- self.ownerVault.withdraw(amount: request)
            self.withdrawalLimit = self.withdrawalLimit - request
            return <- Vault
        }

        destroy() {
          destroy self.ownerVault
      }
    }

    // Resource that the Child will use to withdraw from the fund
    pub resource Admin {
        pub let fund: Capability<&Fund>

        init(_myFund: Capability<&Fund>) {
            self.fund = _myFund
        }

        pub fun adminWithdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.fund.borrow()!.withdrawalLimit >= amount: "Don't be creedy, my child!"
            }

            return <- self.fund.borrow()!.withdrawFromFund(request: amount)
        }
    }

    // Resource that the Parents will use to increase the withdrawal limit
    pub resource ParentsAdmin {

        pub let fund: Capability<&Fund>

        init(_myFund: Capability<&Fund>) {
            self.fund = _myFund
        }

        pub fun increaseWithdrawalLim(newLim: UFix64) {
            self.fund.borrow()!.increaseWithdrawalLimit(newLimit: newLim)
        }
    }

    pub fun createFund(vault: @FungibleToken.Vault, _limit: UFix64): @Fund {
        return <- create Fund(vault: <- vault, limit: _limit)
    }

    pub fun createParentsAdmin(myFund: Capability<&Fund>): @ParentsAdmin {
        return <- create ParentsAdmin(_myFund: myFund)
    }

    pub fun createAdmin(myFund: Capability<&Fund>): @Admin {
        return <- create Admin(_myFund: myFund)
    }
}

===================================> Transactions

=======> Setup Accounts and Mint
// Setup Account

import FungibleToken from 0x01
import FlowToken from 0x02

transaction {

    // The reference to the FungibleToken receiver
    let receiverRef: &{FungibleToken.Receiver}

    // The reference to the Administrator resource
    let adminRef: &FlowToken.Administrator

	prepare(flowAcct: AuthAccount, parentsAcct: AuthAccount, childAcct: AuthAccount) {

    //Create Empty Flow vault
    let vaultA <- FlowToken.createEmptyVault()
		
		// Store the vault in the account storage
		parentsAcct.save<@FungibleToken.Vault>(<-vaultA, to: /storage/MyFlowVault)

    // Create a public Receiver capability to the Vault
		parentsAcct.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/public/MyFlowTokenReceiver, target: /storage/MyFlowVault)

    //Repeat process
    let vaultB <- FlowToken.createEmptyVault()
		
		childAcct.save<@FungibleToken.Vault>(<-vaultB, to: /storage/MyFlowVault)

		childAcct.link<&FlowToken.Vault{FungibleToken.Receiver, FungibleToken.Balance}>(/public/MyFlowTokenReceiver, target: /storage/MyFlowVault)

    //Get the receiver capability into the receiverRef
    self.receiverRef = parentsAcct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/MyFlowTokenReceiver)
            .borrow()
            ?? panic("Could not borrow receiver reference")
        
    //Get the Administrator resource capability into the adminRef
    self.adminRef = flowAcct.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
        ?? panic("could not borrow minter reference")
	}

  execute {

    //Allows minter to mint up to 1000 tokens
    let minter <- self.adminRef.createNewMinter(allowedAmount: 1000.0)

    //Mints 500 token and deposit them into the Parent's vault
    let parentsVault <-minter.mintTokens(amount: 500.0)

    
    self.receiverRef.deposit(from: <- parentsVault)

    destroy minter

    log("Tokens minted and deposited into Parents's vault")
  }

    post {
        // Check that the capabilities were created correctly
        getAccount(0x04).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/MyFlowTokenReceiver)
                        .check():  
                        "Vault Receiver Reference was not created correctly"
        getAccount(0x05).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/MyFlowTokenReceiver)
                        .check():  
                        "Vault Receiver Reference was not created correctly"
    }
}


=======>  Setup Fund

import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

transaction {
       prepare(fundAcct: AuthAccount, parentsAcct: AuthAccount, childAcct: AuthAccount) {
       let flowVault = parentsAcct.borrow<&{FungibleToken.Receiver, FungibleToken.Provider, FungibleToken.Balance}>(from: /storage/MyFlowVault)
              ?? panic("Could not borrow a reference to the owner's vault")

       let fund <- EducationFund.createFund(vault: <- flowVault.withdraw(amount: 100.0), _limit: 50.0)

       fundAcct.save<@EducationFund.Fund>(<-fund, to: /storage/MyFund)

       fundAcct.link<&EducationFund.Fund{EducationFund.PublicFund}>(/public/MyFundReceiver, target: /storage/MyFund)

       fundAcct.link<&EducationFund.Fund>(/private/FundPrivate, target: /storage/MyFund)

       let privateCapability = fundAcct.getCapability<&EducationFund.Fund>(/private/FundPrivate)

       childAcct.save(<- EducationFund.createAdmin(myFund: privateCapability), to:/storage/Admin)

       parentsAcct.save(<- EducationFund.createParentsAdmin(myFund: privateCapability), to:/storage/ParentsAdmin)

       log("The fund was setup correctly")
       }
}


======> Withdraw from fund

import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

transaction(amount: UFix64) {

    let receiverRef: &{FungibleToken.Receiver}
    let admin: &EducationFund.Admin
    
    //Should only work with the Child's account
    prepare(childAcct: AuthAccount) {
        self.receiverRef = childAcct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/MyFlowTokenReceiver)
            .borrow()
            ?? panic("Could not borrow receiver reference")
            
       self.admin = childAcct.borrow<&EducationFund.Admin>(from: /storage/Admin) ?? panic ("Could not get the Admin reference")

    }

    execute {
        let temporaryVault <- self.admin.adminWithdraw(amount: amount)
        self.receiverRef.deposit(from: <- temporaryVault)
        log("Tokens were withdrawn from the Fund and deposited into child's vault")
    }
}

=======> increase Withdrawal Limit

import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

transaction(newLimit: UFix64) {

    let parentsAdmin: &EducationFund.ParentsAdmin

    prepare(parentsAcct: AuthAccount) {
        self.parentsAdmin = parentsAcct.borrow<&EducationFund.ParentsAdmin>(from: /storage/ParentsAdmin)!
    }

    execute {
        self.parentsAdmin.increaseWithdrawalLim(newLim: newLimit)
        log("The withdrawal limit was increased")
    }
}


===========> Add Money to Fund

import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

transaction(amount: UFix64) {

  // Temporary Vault object that holds the balance that is being transferred
  var temporaryVault: @FungibleToken.Vault

  prepare(acct: AuthAccount) {
    // withdraw tokens from your vault by borrowing a reference to it
    // and calling the withdraw function with that reference
    let vaultRef = acct.borrow<&FungibleToken.Vault>(from: /storage/MyFlowVault)
        ?? panic("Could not borrow a reference to the vault")
      
    self.temporaryVault <- vaultRef.withdraw(amount: amount)
  }

  execute {
    // get the recipient's public account object
    let fund = getAccount(0x03)

    // get the recipient's Receiver reference to their Vault
    // by borrowing the reference from the public capability
    let fundRef = fund.getCapability(/public/MyFundReceiver)
                      .borrow<&EducationFund.Fund{EducationFund.PublicFund}>()
                      ?? panic("Could not borrow a reference to the fund's vault")

    // deposit your tokens to their Vault
    fundRef.depositToFund(deposit: <-self.temporaryVault)

    log("The tokens were deposited to the Fund's vault")
  }
}


=====================================> Scripts
 
======> Check Balance
import FungibleToken from 0x01
import FlowToken from 0x02
import EducationFund from 0x03

pub fun main() {
    let fundAcct = getAccount(0x03)
    let parentsAcct = getAccount(0x04)
    let childAcct = getAccount(0x05)

    let receiverRef = fundAcct.getCapability(/public/MyFundReceiver)
                           .borrow<&EducationFund.Fund{EducationFund.PublicFund}>()
                           ?? panic("Could not borrow a reference to the acct receiver")
    let parentsReceiverRef = parentsAcct.getCapability(/public/MyFlowTokenReceiver)
                            .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
                            ?? panic("Could not borrow a reference to the acct4 receiver")
    let childReceiverRef = childAcct.getCapability(/public/MyFlowTokenReceiver)
                            .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
                            ?? panic("Could not borrow a reference to the acct5 receiver")
    
    log("Fund Balance")
    log(receiverRef.checkBalance())
    log("Account 4 Balance")
    log(parentsReceiverRef.balance)
    log("Account 5 Balance")
    log(childReceiverRef.balance)
}


==========> Instructions

Accounts descriptions: 
    
    0x03 is for the EducationFund, 0x04 is for the parents and 0x05 is for the child


    Setup Instructions: 

    1) - Deploy FungibleToken contract in 0x01.

    2) - Deploy FlowToken contract in 0x02.

    3) - Deploy EducationFund contract in 0x03.

    4) - Open the AccountSetup&Mint transaction. Select accounts 0x02, 0x04 and 0x05, and click send.
    
    5) - Open the SetupFund transaction. Select accounts 0x03, 0x04 and 0x05, and click send.

    6) - Use the GetBalances script to check that the Fund balance is at 100, the parents are at 400 and the child is at 0.

    7) - Open the WithdrawFromFund transaction. Set the 'amount' to 50, the account 0x05 and click send.

    8) - Use the GetBalances script to check that your amount was withdraw from the Fund and deposited to the child.

    9) -  Open the WithdrawFromFund transaction. Set the 'amount' to 10, select the account 0x05 and click send. It should fail because of the withdrawalLimit.

    10) - Open the IncreaseWithdrawalLimit transaction. Set the 'newLimit' to what you wish, select the account 0x04 and click send.

    11) - Reopen the WithdrawFromFund transaction. Set the 'amount' to 10, select the account 0x05 and click send. It should now succeed.

    12) - Open the AddMoneyToFund transaction. You can deposit up to 400 token with account 0x04 since it's what's left in the 0x04 vault, 
    but the AddMoneyToFund will work with any account that has a FlowToken Vault.


    Explainations:

    The goal of the assignment was to make an EducationFund that lives on it's own address and to which anyone could contribute,
    only the parents could increase the withdrawal limit, and only the child could withdraw tokens.

    To achieves this, we made an EducationFund contract in 0x03 that has a main 'Fund' body, and 2 roles ('Admin' and 'AdminParents').
    'Admin' represent the child and has access to the adminWithdraw() function. The 'admin' role is a resource since I wanted to use the Cadence language
    main raison d'etre, but I'm not sure I did a great job of it since it was the first time I used Cadence.
    'AdminParents' is also a resource that has access to the increaseWithdrawalLim() function.

    I could have used some address check to only allow 0x05 to withdraw, but that seemed cheap and too much like Solidity.

    The 'AccountSetpup&Mint' transaction simply creates FlowToken vaults into 0x02, 0x04 and 0x05 for later use and mint 500 tokens to the parents (0x04) vault.

    During the execution of the 'SetupFund' transaction, a FlowToken Vault is set into the Fund resource and the parents deposit 100 Flow tokens into the fund.
    The 'PublicFund' resource interface is linked to the public part of 0x03 account so anyone can send tokens to fund's vault.
    The 'Fund' resource is linked to the private part of 0x03 account for later use.
    We use getCapacity on the 'Fund' resource kept in the private part of 0x03's account and use that to create the 'Admin' and 'AdminParents' resources.
    'Admin' is saved into 0x05's storage and 'AdminParents' is saved into 0x04's storage.

    I have to admit that I spent way too much time on this assignment (more than 40h with completing the playground, reading the docs and trying to put everything together 
    into a working fund). I'm sure I could have made better use of resources, but overall I'm happy it works (as far as I can say), and I'm loonking forward to discussing 
    with you what I could have done better.

    If you are still reading this, thank you for your attention.
    


