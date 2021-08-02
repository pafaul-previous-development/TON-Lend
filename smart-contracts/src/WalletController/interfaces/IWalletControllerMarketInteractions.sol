pragma ton-solidity >= 0.39.0;

interface IWalletControllerMarketInteractions {
    function transferTokensToWallet(address destination, uint128 amount, TvmCell payload) external view;
}