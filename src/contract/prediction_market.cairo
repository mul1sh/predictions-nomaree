use starknet::StorageAccess;
use starknet::ContractAddress;
use starknet::StorageBaseAddress;
use starknet::SyscallResult;
use starknet::storage_read_syscall;
use starknet::storage_write_syscall;
use starknet::storage_address_from_base_and_offset;
use traits::{Into, TryInto};
use option::OptionTrait;

#[derive(Drop, Serde)]
struct Prediction {
    participant: ContractAddress,
    amount: u256,
    candidate: felt252,
    redeemed: felt252,
}

impl PredicitionStorageAccess of StorageAccess::<Prediction> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult::<Prediction> {
        Result::Ok(
            Prediction {
                participant: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 0_u8)
                )?.try_into().unwrap(),
                amount: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 1_u8)
                )?.into(),
                candidate: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 2_u8)
                )?,
                redeemed: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 3_u8)
                )?,
            }
        )
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: Prediction) -> SyscallResult::<()> {
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 0_u8), value.participant.into()
        );
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 1_u8), value.amount.try_into().unwrap()
        );
         storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 2_u8), value.candidate.into()
        );
         storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 3_u8), value.redeemed.into()
        )
    }
}

#[contract]
mod PredictionMarket {
    use prediction_market::contract::IERC20::IERC20DispatcherTrait;
    use prediction_market::contract::IERC20::IERC20Dispatcher;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, contract_address::Felt252TryIntoContractAddress
    };
    use super::Prediction;
  
    // public contract storage
    struct Storage {
        predictions: LegacyMap::<ContractAddress, Prediction>,
        token: ContractAddress,
        oracle: ContractAddress
    }

    #[event]
    fn NewBetMarket(participant: ContractAddress, amount: u256, candidate: felt252) {}

    #[constructor]
    fn constructor(_tokenAddress:  ContractAddress, _oracleAddress: ContractAddress){
        token::write(_tokenAddress);
        oracle::write(_oracleAddress);
    }

    #[external]
    fn makePrediction(_candidate: felt252, _amount: u256) {
        let caller = get_caller_address();
        let this_contract = get_contract_address();

        // check that the user has beforehand approved the address of the prediction market to spend the prediction/betting amount of the token
        let allowance = IERC20Dispatcher {contract_address: token::read()}.allowance(caller, this_contract);
        assert(allowance >= _amount, 'Contract not approved');

        // check if the user has enough balance
        let userBal = IERC20Dispatcher {contract_address: token::read()}.balance_of(caller);
        assert(userBal >= _amount, 'Amount less than user balance');

        // if everything checks out, transfer the token amount from user to contract
        IERC20Dispatcher {contract_address: token::read()}.transfer_from(caller, this_contract, _amount);

        // once the transfer is successful write a mapping of the prediction for this user address
        let bet = Prediction {
            participant: caller,
            amount: _amount,
            candidate: _candidate,
            redeemed: bool_to_felt252(false),
        };

        // set the users bet
        predictions::write(caller, bet);
       
    }

    #[external]
    fn redeemRewards(recipient: ContractAddress, amount: u256)  {
       
    }

    #[external]
    fn withdrawTokens(recipient: ContractAddress, amount: u256)  {
        
    }

   


}