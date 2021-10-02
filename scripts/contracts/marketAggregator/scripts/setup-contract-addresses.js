const { convertCrystal } = require("locklift/locklift/utils");
const { operationFlags } = require("../../../utils/common/_transferFlags");
const { loadEssentialContracts } = require("../../../utils/common/_utils");

async function main() {
    let contracts = await loadEssentialContracts({
        wallet: true,
        market: true,
        oracle: true,
        userAM: true,
        walletC: true,
        marketModules: true
    });

    /**
     * @type {String[]}
     */
    let payloads = [];
    payloads.push(await contracts.marketsAggregator.setOracleAddress({
        _oracle: contracts.oracle.address
    }));

    payloads.push(await contracts.marketsAggregator.setUserAccountManager({
        _userAccountManager: contracts.userAccountManager.address
    }));

    payloads.push(await contracts.marketsAggregator.setWalletController({
        _tip3WalletController: contracts.walletController.address
    }));

    for (let payload of payloads) {
        await contracts.msigWallet.transfer({
            destination: contracts.marketsAggregator.address,
            value: convertCrystal(1, 'nano'),
            flags: operationFlags.FEE_FROM_CONTRACT_BALANCE,
            bounce: false,
            payload
        });
    }

    console.log(`MarketsAggregator service address setup finished`);

    for (let moduleName of contracts.modules) {
        /**
         * @type {Module}
         */
        let module = contracts.modules[moduleName];

        let operationId = await module.sendActionId({});

        let modulePayload = await contracts.marketsAggregator.addModule({
            operationId,
            module: module.address
        });

        await contracts.msigWallet.transfer({
            destination: contracts.marketsAggregator.address,
            value: convertCrystal(2, 'nano'),
            flag: operationFlags.FEE_FROM_CONTRACT_BALANCE,
            bounce: false,
            payload: modulePayload
        });
    }

    console.log('Modules for markets are set up');
}

main().then(
    () => process.exit(0)
).catch(
    (err) => {
        console.log(err);
        process.exit(1);
    }
)