#[abi]
trait IOracle {
    #[external]
    fn getPredictionWinner() -> felt252;
}