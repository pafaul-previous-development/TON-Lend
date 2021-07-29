pragma ton-solidity ^0.39.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

interface IOracleService {
    struct OracleServiceInformation {
        uint32 codeVersion;
        address ownerAddress;
        uint256 ownerPubkey;
    }
    
    function getVersion() virtual external responsible view returns (uint32);
    function getDetails() virtual external responsible view returns (OracleServiceInformation);

    function changeOwnerPubkey(uint256 newOwnerPubkey) virtual external;
    function changeOwnerAddress(address newOwnerAddress) virtual external;

    function setTIP3ControllerAddress(address newTip3Controller) virtual external;
}