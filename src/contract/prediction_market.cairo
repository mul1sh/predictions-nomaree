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
    tokenAmount: u256,
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
                tokenAmount: storage_read_syscall(
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
            address_domain, storage_address_from_base_and_offset(base, 1_u8), value.tokenAmount.try_into().unwrap()
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
    use prediction_market::contract::IOracle::IOracleDispatcherTrait;
    use prediction_market::contract::IOracle::IOracleDispatcher;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, contract_address::Felt252TryIntoContractAddress
    };
    use super::Prediction;
    use zeroable::Zeroable;
    use starknet::get_block_timestamp;
    use integer::u256_from_felt252;
  
    // public contract storage
    struct Storage {
        predictions: LegacyMap::<felt252, Prediction>,
        user_balances:  LegacyMap::<ContractAddress, u256>,
        token: ContractAddress,
        oracle: ContractAddress,
        totalTokens: felt252,
        totalPayout: felt252,
        winnerIndex: u8,
        deadline: u64
    }

    #[event]
    fn NewPredictionMarket(predictionID: felt252, participant: ContractAddress, amount: u256, candidate: felt252) {}

    #[constructor]
    fn constructor(_tokenAddress:  ContractAddress, _oracleAddress: ContractAddress, _totalTokens: felt252, _totalPayout: felt252, _winnerIndex: u8, _deadline: u64){
        assert(!_tokenAddress.is_zero(), 'Zero Address not allowed');
        assert(!_oracleAddress.is_zero(), 'Zero Address not allowed');

        // update the public vars of this prediction market
        token::write(_tokenAddress);
        oracle::write(_oracleAddress);
        totalTokens::write(_totalTokens);
        totalPayout::write(_totalPayout);
        winnerIndex::write(_winnerIndex);
        deadline::write(_deadline);
    }

    #[external]
    fn makePrediction(_predictionID: felt252, _candidate: felt252, _amount: u256) {
        let caller = get_caller_address();
        let this_contract = get_contract_address();
        let token_address = token::read();

        // check that the user has beforehand approved the address of the prediction market to spend the prediction/betting amount of the token
        let allowance = IERC20Dispatcher {contract_address: token_address }.allowance(caller, this_contract);
        assert(allowance >= _amount, 'Contract not approved');

        // check if the user has enough balance
        let userTokenBal = IERC20Dispatcher {contract_address: token_address }.balance_of(caller);
        assert(userTokenBal >= _amount, 'User balance less than amount');

        // if everything checks out, transfer the token amount from user to contract
        IERC20Dispatcher {contract_address: token_address }.transfer_from(caller, this_contract, _amount);

        // once the transfer is successful write a mapping of the prediction for this user address
        let p = Prediction {
            participant: caller,
            tokenAmount: _amount,
            candidate: _candidate,
            redeemed: bool_to_felt252(false),
        };

        // set the users prediction in the mapping
        predictions::write(_predictionID, p);

        // update the user balances
        let user_bal = user_balances::read(caller);
        let new_user_bal = user_bal + _amount;

        user_balances::write(caller, new_user_bal);

        // emit a new prediction event
        NewPredictionMarket(_predictionID, caller, _amount, _candidate) 
    }

    #[external]
    fn redeemRewards(_predictionID: felt252)  {
        // get the winner and stored predictions
        let p = predictions::read(_predictionID);
        let winner = IOracleDispatcher{ contract_address: oracle::read()}.getPredictionWinner();

        // make sure the deadline has passed before processing any rewards
        assert(get_block_timestamp() > deadline::read(), 'Redeeming before deadline!!');
        // make sure the prediction hasn't been redeemed yet
        assert(p.redeemed == bool_to_felt252(false), 'Already redeemed');
        // make sure that the candidate is the correct winner
        assert(p.candidate == winner, 'Not winner');

        // calc the reward
        let reward = (p.tokenAmount * u256_from_felt252(totalPayout::read())) / u256_from_felt252(totalTokens::read());

        // update the user balances with the new reward
        let caller = get_caller_address();
        let user_bal = user_balances::read(caller);
        let new_user_bal = user_bal + reward;

        user_balances::write(caller, new_user_bal);

        // finally mark the prediction as redeemed
        let newP = Prediction {
            participant: caller,
            tokenAmount: p.tokenAmount,
            candidate: p.candidate,
            redeemed: bool_to_felt252(true),
        };

        predictions::write(_predictionID, newP);
    }

    #[external]
    fn withdrawTokens()  {
        // get the user balances  
        let caller = get_caller_address();
        let user_bal = user_balances::read(caller);

        // make sure they are not zero
        assert(user_bal > 0, 'Nothing to withdraw');
        // transfer the balances to the user
        IERC20Dispatcher {contract_address: token::read() }.transfer(caller, user_bal);

        // update the new user balances to zero
        user_balances::write(caller, 0);
    }
}