pragma ton-solidity >= 0.47.0;

import './interfaces/IModule.sol';

import '../utils/libraries/MsgFlag.sol';

contract WithdrawModule is IModule, IContractStateCache, IContractAddressSG, IWithdrawModule, IUpgradableContract {
    using UFO for uint256;
    using FPO for fraction;

    address owner;
    address marketAddress;
    address userAccountManager;
    uint32 public contractCodeVersion;

    mapping (uint32 => MarketInfo) marketInfo;
    mapping (address => fraction) tokenPrices;

    event TokenWithdraw(uint32 marketId, MarketDelta marketDelta, address tonWallet, uint256 vTokens, uint256 tokensWithdrawn);

    constructor(address _owner) public {
        tvm.accept();
        owner = _owner;
    }

    function upgradeContractCode(TvmCell code, TvmCell updateParams, uint32 codeVersion) external override onlyOwner {
        tvm.rawReserve(msg.value, 2);

        tvm.setcode(code);
        tvm.setCurrentCode(code);

        onCodeUpgrade (
            owner,
            marketAddress,
            userAccountManager,
            marketInfo,
            tokenPrices,
            codeVersion
        );
    }

    function onCodeUpgrade(
        address _owner,
        address _marketAddress,
        address _userAccountManager,
        mapping(uint32 => MarketInfo) _marketInfo,
        mapping(address => fraction) _tokenPrices,
        uint32 _codeVersion
    ) private {
        tvm.accept();
        tvm.resetStorage();
        owner = _owner;
        marketAddress = _marketAddress;
        userAccountManager = _userAccountManager;
        marketInfo = _marketInfo;
        userAccountManager = _userAccountManager;
        contractCodeVersion = _codeVersion;
    }

    function sendActionId() external override view responsible returns(uint8) {
        return {flag: MsgFlag.REMAINING_GAS} OperationCodes.WITHDRAW_TOKENS;
    }

    function getModuleState() external override view returns(mapping(uint32 => MarketInfo), mapping(address => fraction)) {
        return(marketInfo, tokenPrices);
    }

    function setMarketAddress(address _marketAddress) external override onlyOwner {
        tvm.rawReserve(msg.value, 2);
        marketAddress = _marketAddress;
        address(owner).transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
    }

    function setUserAccountManager(address _userAccountManager) external override onlyOwner {
        tvm.rawReserve(msg.value, 2);
        userAccountManager = _userAccountManager;
        address(owner).transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
    }

    function getContractAddresses() external override view responsible returns(address _owner, address _marketAddress, address _userAccountManager) {
        return {flag: MsgFlag.REMAINING_GAS} (owner, marketAddress, userAccountManager);
    }

    function updateCache(address tonWallet, mapping (uint32 => MarketInfo) _marketInfo, mapping (address => fraction) _tokenPrices) external override onlyMarket {
        marketInfo = _marketInfo;
        tokenPrices = _tokenPrices;
        tonWallet.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
    }

    function performAction(uint32 marketId, TvmCell args, mapping (uint32 => MarketInfo) _marketInfo, mapping (address => fraction) _tokenPrices) external override onlyMarket {
        TvmSlice ts = args.toSlice();
        marketInfo = _marketInfo;
        tokenPrices = _tokenPrices;
        (address tonWallet, address userTip3Wallet, uint256 tokensToWithdraw) = ts.decode(address, address, uint256);
        mapping(uint32 => fraction) updatedIndexes = _createUpdatedIndexes();
        IUAMUserAccount(userAccountManager).requestWithdrawInfo{
            flag: MsgFlag.REMAINING_GAS
        }(tonWallet, userTip3Wallet, tokensToWithdraw, marketId, updatedIndexes);
    }

    function _createUpdatedIndexes() internal view returns(mapping(uint32 => fraction) updatedIndexes) {
        for ((uint32 marketId, MarketInfo mi): marketInfo) {
            updatedIndexes[marketId] = mi.index;
        }
    }

    function withdrawTokensFromMarket(
        address tonWallet, 
        address userTip3Wallet,
        uint256 tokensToWithdraw, 
        uint32 marketId, 
        mapping(uint32 => uint256) si,
        mapping(uint32 => uint256) bi
    ) external override onlyUserAccountManager {
        tvm.rawReserve(msg.value - msg.value / 4, 0);
        MarketDelta marketDelta;

        MarketInfo mi = marketInfo[marketId];

        (uint256 supplySum, uint256 borrowSum) = Utilities.calculateSupplyBorrow(si, bi, marketInfo, tokenPrices);

        fraction fTokensToSend = tokensToWithdraw.numFMul(mi.exchangeRate);
        fraction fTokensToSendUSD = fTokensToSend.fDiv(tokenPrices[marketInfo[marketId].token]);
        if (supplySum > borrowSum) {
            if (supplySum - borrowSum > fTokensToSendUSD.toNum()) {
                uint256 tokensToSend = fTokensToSend.toNum();

                marketDelta.realTokenBalance.delta = tokensToSend;
                marketDelta.realTokenBalance.positive = false;
                marketDelta.vTokenBalance.delta = tokensToWithdraw;
                marketDelta.vTokenBalance.positive = false;

                IContractStateCacheRoot(marketAddress).receiveCacheDelta{
                    value: msg.value / 4
                }(tonWallet, marketDelta, marketId);

                emit TokenWithdraw(marketId , marketDelta, tonWallet, tokensToWithdraw, tokensToSend);

                IUAMUserAccount(userAccountManager).writeWithdrawInfo{
                    flag: MsgFlag.REMAINING_GAS
                }(tonWallet, userTip3Wallet, marketId, tokensToWithdraw, tokensToSend);
            } else {
                IUAMUserAccount(userAccountManager).requestUserAccountHealthCalculation{
                    flag: MsgFlag.REMAINING_GAS
                }(tonWallet);
            }
        } else {
            IUAMUserAccount(userAccountManager).requestUserAccountHealthCalculation{
                flag: MsgFlag.REMAINING_GAS
            }(tonWallet);
        }
    }

    modifier onlyMarket() {
        require(msg.sender == marketAddress);
        tvm.rawReserve(msg.value, 2);
        _;
    }

    modifier onlyUserAccountManager() {
        require(msg.sender == userAccountManager);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}