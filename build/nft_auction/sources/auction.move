module nft_auction::auction {

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use nft_auction::nft::NFT;
    use sui::clock::{Self, Clock};
    use sui::event;

    /// Represents an auction for an NFT.
    public struct Auction has key {
        id: UID,
        nft: Option<NFT>, // NFT being auctioned
        seller: address, // The person who instantiates the auction
        highest_bidder: address, // Address of the highest bidder
        current_bid: u64, // Current highest bid
        min_bid: u64, // Minimum bid acceptable
        end_time: u64, // Auction end time in Sui epoch time units (ms).
        coin_balance: Balance<SUI>, // Assists in transferring the payment to the seller
        auction_ended: bool, // Indicates whether the auction is still ongoing
    }

    // Event struct definitions...

    /// Error constants
    const ETimeExpired: u64 = 0;
    const EBidTooLow: u64 = 1;
    const EAuctionNotEnded: u64 = 2;
    const ENotWinner: u64 = 3;
    const ENFTAlreadyClaimed: u64 = 4;
    const EZeroDuration: u64 = 5;
    const EZeroBid: u64 = 6;

    /// Creates a new auction for an NFT.
    ///
    /// # Arguments
    ///
    /// * `nft` - The NFT to be auctioned.
    /// * `min_bid` - The minimum acceptable bid.
    /// * `duration` - Duration of the auction in milliseconds.
    /// * `clock` - Reference to the clock object.
    /// * `ctx` - Mutable reference to the transaction context.
    ///
    /// # Panics
    ///
    /// Panics if `min_bid` is zero or `duration` is zero.
    public entry fun create_auction(nft: NFT, min_bid: u64, duration: u64, clock: &Clock, ctx: &mut TxContext) {
        assert!(min_bid > 0, EZeroBid);
        assert!(duration > 0, EZeroDuration);
        
        let end_time = clock::timestamp_ms(clock) + duration;
        let seller = tx_context::sender(ctx);
        let nft_id = object::id(&nft);

        let auction = Auction {
            id: object::new(ctx),
            nft: std::option::some(nft),
            seller,
            highest_bidder: seller,
            current_bid: min_bid,
            min_bid,
            end_time,
            coin_balance: balance::zero(),
            auction_ended: false,
        };

        event::emit(AuctionCreated {
            auction_id: object::id(&auction),
            nft_id,
            seller,
            start_price: min_bid,
            end_time,
        });       

        transfer::share_object(auction);   
    }

    /// Places a bid in an ongoing auction.
    ///
    /// # Arguments
    ///
    /// * `auction` - Mutable reference to the auction object.
    /// * `clock` - Reference to the clock object.
    /// * `amount` - Mutable reference to the coin representing the bid amount.
    /// * `ctx` - Mutable reference to the transaction context.
    ///
    /// # Panics
    ///
    /// Panics if the bid amount is zero, the auction has ended, or the bid amount is less than the current highest bid.
    public entry fun place_bid(auction: &mut Auction, clock: &Clock, amount: &mut Coin<SUI>, ctx: &mut TxContext) {
        let bid_amount = coin::value(amount);
        assert!(bid_amount > auction.current_bid, EBidTooLow);

        let now = clock::timestamp_ms(clock);
        assert!(now < auction.end_time, ETimeExpired);

        let bidder = tx_context::sender(ctx);

        if (auction.highest_bidder != auction.seller) {
            transfer::public_transfer(
                coin::split(amount, auction.current_bid, ctx),
                auction.highest_bidder
            );
        }

        auction.current_bid = bid_amount;
        auction.highest_bidder = bidder;

        update_balance_with_coin(auction, bid_amount, amount, ctx);

        event::emit(BidPlaced {
            auction_id: object::id(auction),
            bidder,
            amount: bid_amount,
        });
    }

    /// Updates the coin balance of the auction.
    ///
    /// # Arguments
    ///
    /// * `auction` - Mutable reference to the auction object.
    /// * `new_amount` - New amount to be added to the auction's coin balance.
    /// * `payment` - Mutable reference to the coin representing the payment.
    /// * `ctx` - Mutable reference to the transaction context.
    public fun update_balance_with_coin(auction: &mut Auction, new_amount: u64, payment: &mut Coin<SUI>, ctx: &mut TxContext) {
        let added = coin::split(payment, new_amount - balance::value(&auction.coin_balance), ctx);
        balance::join(&mut auction.coin_balance, coin::into_balance(added));
    }

    /// Ends the auction.
    ///
    /// # Arguments
    ///
    /// * `auction` - Mutable reference to the auction object.
    /// * `clock` - Reference to the clock object.
    /// * `ctx` - Mutable reference to the transaction context.
    ///
    /// # Panics
    ///
    /// Panics if the auction has not ended yet.
    public entry fun end_auction(auction: &mut Auction, clock: &Clock, ctx: &mut TxContext) {
        assert!(clock::timestamp_ms(clock) >= auction.end_time, EAuctionNotEnded);
        
        auction.auction_ended = true;

        if (auction.highest_bidder == auction.seller) {
            let nft = std::option::extract(&mut auction.nft);
            transfer::public_transfer(nft, auction.seller);

            event::emit(AuctionEndedNoBids {
                auction_id: object::id(auction),
                seller: auction.seller,
            });
        } else {
            let winner = auction.highest_bidder;
            let final_price = auction.current_bid;

            transfer::public_transfer(
                coin::take(&mut auction.coin_balance, final_price, ctx),
                auction.seller
            );

            event::emit(AuctionEnded {
                auction_id: object::id(auction),
                winner,
                final_price,
            });
        }
    }

    /// Allows the winner to claim their NFT.
    ///
    /// # Arguments
    ///
    /// * `auction` - Mutable reference to the auction object.
    /// * `ctx` - Mutable reference to the transaction context.
    ///
    /// # Panics
    ///
    /// Panics if the auction has not ended, the caller is not the winner, or the NFT has already been claimed.
    public fun claim_nft(auction: &mut Auction, ctx: &mut TxContext) {
        assert!(auction.auction_ended, EAuctionNotEnded);
        assert!(tx_context::sender(ctx) == auction.highest_bidder, ENotWinner);
        assert!(std::option::is_some(&auction.nft), ENFTAlreadyClaimed);

        let winner = auction.highest_bidder;
        let nft = std::option::extract(&mut auction.nft);

        transfer::public_transfer(nft, winner);

        event::emit(NFTClaimed {
            auction_id: object::id(auction),
            winner,
        });
    }

    // Getter functions for testing
    public fun current_bid(auction: &Auction): u64 {
        auction.current_bid
    }

    public fun highest_bidder(auction: &Auction): address {
        auction.highest_bidder
    }

    public fun auction_ended(auction: &Auction): bool {
        auction.auction_ended
    }
}