module nft_auction::nft {
    
    use std::string::String;
    use sui::object::{Self, UID, new, delete};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::transfer;
    use sui::event;
    use sui::address;

    // Error constants
    const EEmptyString: u64 = 1;

    // The struct defining our NFT object
    public struct NFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: String,
    }

    // Event emitted when an NFT is minted
    public struct NFTMinted has copy, drop {
        id: UID,
        creator: address,
    }

    // Event emitted when an NFT is transferred
    public struct NFTTransferred has copy, drop {
        id: UID,
        from: address,
        to: address,
    }

    // Event emitted when an NFT is burned
    public struct NFTBurned has copy, drop {
        id: UID,
        owner: address,
    }

    // Function for minting a new NFT
    public entry fun mint(name: String, description: String, image_url: String, ctx: &mut TxContext) {
        // Validation checks
        assert!(!std::string::is_empty(&name), EEmptyString);
        assert!(!std::string::is_empty(&description), EEmptyString);
        assert!(!std::string::is_empty(&image_url), EEmptyString);

        // Create the NFT
        let nft = NFT {
            id: new(ctx),
            name: name,
            description: description,
            image_url: image_url,
        };

        // Create variable to send the nft to creator
        let sender = sender(ctx);

        // Transfer the nft to the owner
        transfer::public_transfer(nft, sender);

        // Emit NFTMinted event
        event::emit(NFTMinted {
            id: nft.id,
            creator: sender,
        });
    }

    // Function to transfer an NFT to another address
    public entry fun transfer_nft(nft: NFT, recipient: address, ctx: &mut TxContext) {
        let sender = sender(ctx);

        // Transfer the NFT to the recipient
        transfer::public_transfer(nft, recipient);

        // Emit NFTTransferred event
        event::emit(NFTTransferred {
            id: nft.id,
            from: sender,
            to: recipient,
        });
    }

    // Function to burn an NFT
    public entry fun burn_nft(nft: NFT, ctx: &mut TxContext) {
        let owner = sender(ctx);

        // Emit NFTBurned event before destruction
        event::emit(NFTBurned {
            id: nft.id,
            owner: owner,
        });

        // Destroy the NFT
        delete(&nft.id, ctx);
    }

    // Getter functions for testing
    public fun name(nft: &NFT): &String {
        &nft.name
    }

    public fun description(nft: &NFT): &String {
        &nft.description
    }

    public fun image_url(nft: &NFT): &String {
        &nft.image_url
    }
}
