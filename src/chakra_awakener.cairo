use starknet::ContractAddress;

#[starknet::interface]
trait IChakraAwakener<TContractState> {
    fn add_white_list(ref self: TContractState, user: ContractAddress);
    fn remove_white_list(ref self: TContractState, user: ContractAddress);
    fn in_white_list(self: @TContractState, user: ContractAddress) -> bool;
    fn mint(ref self: TContractState, minter: ContractAddress);
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> Array<felt252>;
    fn tokenURI(self: @TContractState, tokenId: u256) -> Array<felt252>;
}

#[starknet::contract]
mod ChakraAwakener{
    use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::interface::{IERC721, IERC721Metadata, IERC721CamelOnly};
    use openzeppelin::access::ownable::interface::IOwnable;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use chakra_awakener_contract::merkle_tree::MerkleTree;
    use chakra_awakener_contract::merkle_tree::MerkleTreeTrait;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    /// Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // merkle_root: felt252,
        white_list: LegacyMap<ContractAddress, bool>,
        minted: u256,
        is_minted: LegacyMap<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    mod Errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC721: invalid token ID';
        const INVALID_ACCOUNT: felt252 = 'ERC721: invalid account';
        const UNAUTHORIZED: felt252 = 'ERC721: unauthorized caller';
        const APPROVAL_TO_OWNER: felt252 = 'ERC721: approval to owner';
        const SELF_APPROVAL: felt252 = 'ERC721: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC721: invalid receiver';
        const ALREADY_MINTED: felt252 = 'ERC721: token already minted';
        const WRONG_SENDER: felt252 = 'ERC721: wrong sender';
        const SAFE_MINT_FAILED: felt252 = 'ERC721: safe mint failed';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC721: safe transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress
    ) {
        let name = 'Chakra Awakener';
        let symbol = 'AWAKE';
        self.ownable.initializer(owner);
        self.erc721.initializer(name, symbol);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();

            // Replace the class hash upgrading the contract
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl ChakraAwakenerImpl of super::IChakraAwakener<ContractState>{
        
        fn add_white_list(ref self: ContractState, user: ContractAddress){
            self.ownable.assert_only_owner();
            self.white_list.write(user, true);
        }
        fn remove_white_list(ref self: ContractState, user: ContractAddress){
            self.ownable.assert_only_owner();
            self.white_list.write(user, false);
        }

        fn in_white_list(self: @ContractState, user: ContractAddress) -> bool{
            return self.white_list.read(user);
        }

        fn mint(ref self: ContractState, minter: ContractAddress){
            assert(self.white_list.read(minter), 'not in white list');
            assert(!self.is_minted.read(minter), 'ready minted');
            assert(self.minted.read() <= 888, 'total supply is 888');
            let minted = self.minted.read();
            self.erc721._mint(minter, minted+1);
            self.minted.write(minted+1);
            self.is_minted.write(minter, true);
        }

        /// Returns the NFT name.
        fn name(self: @ContractState) -> felt252 {
            self.erc721.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ContractState) -> felt252 {
            self.erc721.ERC721_symbol.read()
        }
        
        fn token_uri(self: @ContractState, token_id: u256) -> Array<felt252> {
            return array!['https://bafybeignkfva3w','oeklqssta5hgmn6htmrf', 'bg5gmrmht4ndxe3zen3g7', 'bbe.ipfs.w3s.link/', 'ChakraAwakenerNFTMetadata.json'];
        }

        fn tokenURI(self: @ContractState, tokenId: u256) -> Array<felt252> {
            self.token_uri(tokenId)
        }

    }

    #[abi(embed_v0)]
    impl ERC721 of IERC721<ContractState> {
        /// Returns the number of NFTs owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), Errors::INVALID_ACCOUNT);
            self.erc721.ERC721_balances.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.erc721._owner_of(token_id)
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            assert(false, 'token is SOUL BOUND');
            assert(
                self.erc721._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self.erc721._safe_transfer(from, to, token_id, data);
        }

        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(false, 'token is SOUL BOUND');
            assert(
                self.erc721._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self.erc721._transfer(from, to, token_id);
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(false, 'token is SOUL BOUND');
            let owner = self.erc721._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || ERC721::is_approved_for_all(@self, owner, caller),
                Errors::UNAUTHORIZED
            );
            self.erc721._approve(to, token_id);
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            assert(false, 'token is SOUL BOUND');
            self.erc721._set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self.erc721._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.erc721.ERC721_token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.erc721.ERC721_operator_approvals.read((owner, operator))
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelOnly of IERC721CamelOnly<ContractState> {
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
            self.owner_of(tokenId)
        }

        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            self.safe_transfer_from(from, to, tokenId, data)
        }

        fn transferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256
        ) {
            self.transfer_from(from, to, tokenId)
        }

        fn setApprovalForAll(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self.set_approval_for_all(operator, approved)
        }

        fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
            self.get_approved(tokenId)
        }

        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.is_approved_for_all(owner, operator)
        }
    }
}