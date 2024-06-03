// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./optimism/IDisputeGame.sol";
import "./optimism/IDisputeGameFactory.sol";
import { Types } from "./optimism/Types.sol";

interface IL2OutputOracle {
    function getL2Output(
        uint256 _l2OutputIndex
    ) external view returns (Types.OutputProposal memory);

    function latestOutputIndex() external view returns (uint256);
}

interface IOptimismPortalOutputRoot {
    function l2Oracle() external view returns (IL2OutputOracle);

    function disputeGameFactory() external view returns (IDisputeGameFactory);

    function respectedGameType() external view returns (GameType);
}