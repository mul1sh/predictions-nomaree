
#[contract]
mod PredictionMarket {

    use integer::BoundedInt;
    use starknet::{
        ContractAddress, get_caller_address, contract_address::Felt252TryIntoContractAddress
    };

    struct Storage {
        participant: ContractAddress,
        amount: u256,
        candidate: felt252,
        redeemed: bool,
        balances: LegacyMap::<ContractAddress, felt252>,
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
    fn makePrediction(_candidate: felt252, amount: u256) {
       
    }

    #[external]
    fn redeemRewards(recipient: ContractAddress, amount: u256)  {
       
    }

    #[external]
    fn withdrawTokens(recipient: ContractAddress, amount: u256)  {
        
    }

   


}