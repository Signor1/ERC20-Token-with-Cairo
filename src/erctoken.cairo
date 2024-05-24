use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn totalSupply(self: @TContractState) -> u256;
    fn balanceOf(self: @TContractState, owner: ContractAddress) -> u256;

    fn transfer(ref self: TContractState, to: ContractAddress, value: u256) -> bool;
    fn transferFrom(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, value: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, value: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    // Mint and Burn
    fn mint(ref self: TContractState, to: ContractAddress, value: u256);
    fn burn(ref self: TContractState, from: ContractAddress, value: u256);
}

#[starknet::contract]
mod ERC20 {
    use core::starknet::event::EventEmitter;
    use super::IERC20;
    use starknet::{ContractAddress, constract_address_const, get_caller_address};

    //added the storage definition
    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        totalSupply: u256,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    }

    //using writing method to write to state
    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252, decimals: u8,) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
    }

    // Events
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Mint {
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Burn {
        from: ContractAddress,
        value: u256,
    }


    // #[external(v0)]
    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn totalSupply(self: @ContractState) -> u256 {
            self.totalSupply.read()
        }

        fn balanceOf(self: @ContractState, owner: ContractAddress) -> u256 {
            self.balances.read(owner)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, to: ContractAddress, value: u256) -> bool {
            let msg_sender = get_caller_address();
            self._transfer(msg_sender, to, value)
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, value: u256
        ) -> bool {
            let msg_sender = get_caller_address();
            let allowance = self.allowance(from, msg_sender);
            assert(allowance >= value, 'Insufficient allowance');
            self._transfer(from, to, value);
            self.allowances.write((from, msg_sender), allowance - value);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, value: u256) -> bool {
            let msg_sender = get_caller_address();
            self.allowances.write((msg_sender, spender), value);
            self.emit(Approval { owner: msg_sender, spender: spender, value: value, });
            true
        }

        // mint
        fn mint(ref self: ContractState, to: ContractAddress, value: u256) {
            let total_supply = self.totalSupply.read();
            self.totalSupply.write(total_supply + value);
            let balance = self.balances.read(to);
            self.balances.write(to, balance + value);
            self.emit(Mint { to: to, value: value, });
        }

        // burn
        fn burn(ref self: ContractState, from: ContractAddress, value: u256) {
            let balance = self.balances.read(from);
            assert(balance >= value, 'Insufficient balance');
            self.balances.write(from, balance - value);
            let total_supply = self.totalSupply.read();
            self.totalSupply.write(total_supply - value);
            self.emit(Burn { from: from, value: value, });
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, value: u256
        ) -> bool {
            let address_zero: ContractAddress = ContractAddress::zero();
            assert(from != address_zero);
            assert(to != address_zero);
            assert(value > 0);
            assert(self.balances.read(from) >= value);

            self.balances.write(from, self.balances.read(from) - value);
            self.balances.write(to, self.balances.read(to) + value);
            self.emit(Transfer { from: from, to: to, value: value, });
            true
        }
    }
}
