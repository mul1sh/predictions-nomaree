#[contract]
mod Oracle {

    struct Storage {
        winningCandidate: felt252,
    }

    #[constructor]
    fn constructor(_winningCandidate: felt252){
        winningCandidate::write(_winningCandidate)
    }

     #[external]
    fn getPredictionWinner() -> felt252{
        winningCandidate::read()
    }

}