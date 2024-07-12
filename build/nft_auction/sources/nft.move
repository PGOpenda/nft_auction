module nft_auction::nft {

    use std::string::String;
    use sui::event;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object;

    /// Event emitted when an NFT is minted.
    public struct NFTMinted has copy, drop {
        id: ID,
        owner: address,
    }

    /// Event emitted when an NFT is transferred.
    public struct NFTTransferred has copy, drop {
        id: ID,
        from: address,
        to: address,
    }

    /// Event emitted when an NFT is burned.
    public struct NFTBurned has copy, drop {
        id: ID,
        owner: address,
    }

    /// Represents an NFT with a unique ID, name, description, and image URL.
    public struct NFT has key, store {
        id: UID,  // Unique identifier for the NFT
        name: String,  // Name of the NFT
        description: String,  // Description of the NFT
        image_url: String,  // URL to the image representing the NFT
    }

    /// Mints a new NFT and transfers it to the creator.
    ///
    /// # Arguments
    ///
    /// * `name` - Name of the NFT.
    /// * `description` - Description of the NFT.
    /// * `image_url` - URL to the image representing the NFT.
    /// * `ctx` - Mutable reference to the transaction context.
    public entry fun mint(name: String, description: String, image_url: String, ctx: &mut TxContext) {
        let nft = NFT {
            id: object::new(ctx),
            name: name,
            description: description,
            image_url: image_url,
        };

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(nft, sender);

        event::emit(NFTMinted {
            id: object::id(&nft),
            owner: sender,
        });
    }

    /// Transfers the NFT to the recipient if the sender is the owner.
    ///
    /// # Arguments
    ///
    /// * `nft` - The NFT to be transferred.
    /// * `recipient` - Address of the new owner.
    /// * `ctx` - Mutable reference to the transaction context.
    ///
    /// # Panics
    ///
    /// Panics if the sender is not the owner of the NFT.
    public entry fun transfer_nft(nft: NFT, recipient: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(object::owner(&nft.id) == sender, "Unauthorized transfer");
        transfer::public_transfer(nft, recipient);

        event::emit(NFTTransferred {
            id: object::id(&nft),
            from: sender,
            to: recipient,
        });
    }

    /// Burns (destroys) the given NFT.
    ///
    /// # Arguments
    ///
    /// * `nft` - The NFT to be burned.
    /// * `ctx` - Mutable reference to the transaction context.
    ///
    /// # Panics
    ///
    /// Panics if the sender is not the owner of the NFT.
    public entry fun burn_nft(nft: NFT, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(object::owner(&nft.id) == sender, "Unauthorized burn");
        object::delete(nft.id, ctx);

        event::emit(NFTBurned {
            id: object::id(&nft),
            owner: sender,
        });
    }

    /// Getter function for the name of the NFT.
    ///
    /// # Arguments
    ///
    /// * `nft` - Reference to the NFT.
    ///
    /// # Returns
    ///
    /// The name of the NFT.
    public fun name(nft: &NFT): String {
        nft.name.clone()
    }

    /// Getter function for the description of the NFT.
    ///
    /// # Arguments
    ///
    /// * `nft` - Reference to the NFT.
    ///
    /// # Returns
    ///
    /// The description of the NFT.
    public fun description(nft: &NFT): String {
        nft.description.clone()
    }

    /// Getter function for the image URL of the NFT.
    ///
    /// # Arguments
    ///
    /// * `nft` - Reference to the NFT.
    ///
    /// # Returns
    ///
    /// The image URL of the NFT.
    public fun image_url(nft: &NFT): String {
        nft.image_url.clone()
    }
}
