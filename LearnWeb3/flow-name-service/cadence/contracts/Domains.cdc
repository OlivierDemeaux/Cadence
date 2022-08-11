import NonFungibleToken from "./interfaces/NonFungibleToken.cdc"
import FungibleToken from "./interfaces/FungibleToken.cdc"
import FlowToken from "./tokens/FlowToken.cdc"

// The Domains contract defines the Domains NFT Collection
// to be used by flow-name-service
pub contract Domains: NonFungibleToken {
    // We will write the rest of our code here

    // Struct that represents information about an FNS domain
    pub struct DomainInfo {
        // Public Variables of the Struct
        pub let id: UInt64
        pub let owner: Address
        pub let name: String
        pub let nameHash: String
        pub let expiresAt: UFix64
        pub let address: Address?
        pub let bio: String
        pub let createdAt: UFix64
        pub let owners: {String: Address}
        pub let expirationTimes: {String: UFix64}

        pub event DomainBioChanged(nameHash: String, bio: String)
        pub event DomainAddressChanged(nameHash: String, address: Address)

        // Checks if a domain is available for sale
        pub fun isAvailable(nameHash: String): Bool {
            if self.owners[nameHash] == nil {
            return true
            }
            return self.isExpired(nameHash: nameHash)
        }

        // Returns the expiry time for a domain
        pub fun getExpirationTime(nameHash: String): UFix64? {
            return self.expirationTimes[nameHash]
        }

        // Checks if a domain is expired
        pub fun isExpired(nameHash: String): Bool {
            let currTime = getCurrentBlock().timestamp
            let expTime = self.expirationTimes[nameHash]
            if expTime != nil {
                return currTime >= expTime!
            }
            return false
        }

        // Returns the entire `owners` dictionary
        pub fun getAllOwners(): {String: Address} {
            return self.owners
        }

        // Returns the entire `expirationTimes` dictionary
        pub fun getAllExpirationTimes(): {String: UFix64} {
            return self.expirationTimes
        }

        // Update the owner of a domain
        access(account) fun updateOwner(nameHash: String, address: Address) {
            self.owners[nameHash] = address
        }

        // Update the expiration time of a domain
        access(account) fun updateExpirationTime(nameHash: String, expTime: UFix64) {
            self.expirationTimes[nameHash] = expTime
        }

        // Struct initializer
        init(
            id: UInt64,
            owner: Address,
            name: String,
            nameHash: String,
            expiresAt: UFix64,
            address: Address?,
            bio: String,
            createdAt: UFix64
        ) {
            self.id = id
            self.owner = owner
            self.name = name
            self.nameHash = nameHash
            self.expiresAt = expiresAt
            self.address = address
            self.bio = bio
            self.createdAt = createdAt
        }
    }

    pub resource interface DomainPublic {
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64
        
        pub fun getBio(): String
        pub fun getAddress(): Address?
        pub fun getDomainName(): String
        pub fun getInfo(): DomainInfo
    }

    pub resource interface DomainPrivate {
        pub fun setBio(bio: String)
        pub fun setAddress(addr: Address)
    }

    pub resource NFT: DomainPublic, DomainPrivate, NonFungibleToken.INFT {
    // Rest of the code under this subheading goes here
        pub let id: UInt64
        pub let name: String
        pub let nameHash: String
        pub let createdAt: UFix64

        // access(self) implies that only the code within this resource
        // can read/modify this variable directly
        // This is similar to `private` in Solidity
        access(self) var address: Address?
        access(self) var bio: String

        init(id: UInt64, name: String, nameHash: String) {
            self.id = id
            self.name = name
            self.nameHash = nameHash
            self.createdAt = getCurrentBlock().timestamp
            self.address = nil
            self.bio = ""
        }

        pub fun getBio(): String {
            return self.bio
        }

        pub fun setBio(bio: String) {
            // This is like a `require` statement in Solidity
            // A 'pre'-check to running this function
            // If the condition is not valid, it will throw the given error
            pre {
                Domains.isExpired(nameHash: self.nameHash) == false : "Domain is expired"
            }
            self.bio = bio
            emit DomainBioChanged(nameHash: self.nameHash, bio: bio)
        }

        pub fun getAddress(): Address? {
            return self.address
        }

        pub fun setAddress(addr: Address) {
            pre {
                Domains.isExpired(nameHash: self.nameHash) == false : "Domain is expired"
            }

            self.address = addr
            emit DomainAddressChanged(nameHash: self.nameHash, address: addr)
        }

        pub fun getDomainName(): String {
            return self.name.concat(".fns")
        }

        pub fun getInfo(): DomainInfo {
            let owner = Domains.owners[self.nameHash]!

            return DomainInfo(
                id: self.id,
                owner: owner,
                name: self.getDomainName(),
                nameHash: self.nameHash,
                expiresAt: Domains.expirationTimes[self.nameHash]!,
                address: self.address,
                bio: self.bio,
                createdAt: self.createdAt
            )
        }
    }
}