rm -rf ./npm/contracts
mkdir ./npm/contracts

ln -s ../lib/optimism/packages/contracts-bedrock/src/dispute ./src/dispute

forge flatten --output npm/contracts/interfaces/optimism/IDisputeGameFactory.sol src/interfaces/optimism/IDisputeGameFactory.sol
forge flatten --output npm/contracts/interfaces/optimism/Types.sol src/interfaces/optimism/Types.sol

cp ./lib/optimism/packages/contracts-bedrock/src/dispute/interfaces/IFaultDisputeGame.sol npm/contracts/interfaces/optimism/IFaultDisputeGame.sol
sed -i '' 's|import "src/dispute/lib/Types.sol";|import "./IDisputeGameFactory.sol";|g' npm/contracts/interfaces/optimism/IFaultDisputeGame.sol
sed -i '' 's|import { IDisputeGame } from "./IDisputeGame.sol";|// lib/optimism/packages/contracts-bedrock/src/dispute/interfaces/IFaultDisputeGame.sol|g' npm/contracts/interfaces/optimism/IFaultDisputeGame.sol

cp src/interfaces/IOptimismPortalOutputRoot.sol npm/contracts/interfaces/IOptimismPortalOutputRoot.sol
cp src/DisputeGameLookup.sol npm/contracts/DisputeGameLookup.sol
cp src/L2OutputOracleLookup.sol npm/contracts/L2OutputOracleLookup.sol
cp src/OPOutputLookup.sol npm/contracts/OPOutputLookup.sol

rm ./src/dispute