const { convertCrystal } = require("locklift/locklift/utils");
const { loadEssentialContracts } = require("../../../utils/contracts");
const marketToAdd = require("../modules/market-to-add");

async function main() {
    let contracts = await loadEssentialContracts({
        wallet: true,
        market: true
    });

    let addMarketPayload = await contracts.marketsAggregator.createNewMarket({...marketToAdd});

    await contracts.msigWallet.transfer({
        destination: contracts.marketsAggregator.address,
        value: convertCrystal(10, 'nano'),
        payload: addMarketPayload
    });
}

main().then(
    () => process.exit(0)
).catch(
    (err) => {
        console.log(err);
        process.exit(1);
    }
)