pragma ton-solidity >= 0.39.0;
pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

interface IContractControllerCodeManager {
    struct CodeStorage {
        TvmCell code;
        uint32 codeVersion;
        uint128 deployCost;
    }
    
    function addContractCode(uint8 contractType, TvmCell code, uint32 codeVersion, uint128 deployCost) external;
    function createContract(uint8 contractType, TvmCell initialData, TvmCell params) external;
    function updateContractCode(uint8 contractType, TvmCell code, uint32 codeVersion) external;
    function updateContract(uint8 contractType, address contractAddress, TvmCell updateParams) external;

    function getCodeVersion(uint8 contractType) external responsible returns (uint32);
    function getCodeStorage(uint8 contractType) external responsible returns (CodeStorage);

    function setContractDeployCost(uint8 contractType, uint128 deployCost) external;
}