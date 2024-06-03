// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DisputeGameLookup.sol";
import "./L2OutputOracleLookup.sol";
import "./interfaces/optimism/IFaultDisputeGame.sol";
import "./interfaces/IOptimismPortalOutputRoot.sol";

// For OPVerifier ENS Gateway
enum OPWitnessProofType {
    L2OutputOracle,
    DisputeGame
}

// For OPVerifier ENS Gateway
struct OPProvableBlock {
    OPWitnessProofType proofType;
    uint256 index;
    uint256 blockNumber;
    bytes32 outputRoot;
}

contract OPOutputLookup {
    // ========================
    // Dispute Game
    // ========================

    function getDisputeGame(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 index,
        uint256 minAge,
        uint256 maxAge
    )
        public
        view
        returns (
            bytes32 outputRoot,
            GameType gameType,
            uint64 gameCreationTime,
            IDisputeGame proxy
        )
    {
        return
            DisputeGameLookup.getDisputeGame(
                optimismPortal,
                index,
                minAge,
                maxAge
            );
    }

    function getRespectedDisputeGame(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 index,
        uint256 minAge,
        uint256 maxAge
    )
        public
        view
        returns (
            bytes32 outputRoot,
            GameType gameType,
            uint64 gameCreationTime,
            IDisputeGame proxy
        )
    {
        return
            DisputeGameLookup.getRespectedDisputeGame(
                optimismPortal,
                index,
                minAge,
                maxAge
            );
    }

    function getLatestDisputeGame(
        IOptimismPortalOutputRoot optimismPortal,
        GameType gameType,
        uint256 minAge,
        uint256 maxAge
    )
        public
        view
        returns (
            uint256 disputeGameIndex,
            bytes32 outputRoot,
            uint64 gameCreationTime,
            uint256 blockNumber,
            IDisputeGame proxy
        )
    {
        return
            DisputeGameLookup.getLatestDisputeGame(
                optimismPortal,
                gameType,
                minAge,
                maxAge
            );
    }

    function getLatestRespectedDisputeGame(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 minAge,
        uint256 maxAge
    )
        public
        view
        returns (
            uint256 disputeGameIndex,
            bytes32 outputRoot,
            uint64 gameCreationTime,
            uint256 blockNumber,
            IDisputeGame proxy,
            GameType gameType
        )
    {
        return
            DisputeGameLookup.getLatestRespectedDisputeGame(
                optimismPortal,
                minAge,
                maxAge
            );
    }

    // ========================
    // L2 Output Oracle
    // ========================

    function getLatestL2Output(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 minAge,
        uint256 maxAge
    ) public view returns (uint256 index, Types.OutputProposal memory) {
        return
            L2OutputOracleLookup.getLatestL2Output(
                optimismPortal,
                minAge,
                maxAge
            );
    }

    function getL2Output(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 index,
        uint256 minAge,
        uint256 maxAge
    ) public view returns (Types.OutputProposal memory) {
        return
            L2OutputOracleLookup.getL2Output(
                optimismPortal,
                index,
                minAge,
                maxAge
            );
    }

    // ========================
    // ENS Gateway
    // ========================

    error UnknownProofType();

    function getProofType(
        IOptimismPortalOutputRoot optimismPortal
    ) public view returns (OPWitnessProofType) {
        try optimismPortal.disputeGameFactory() returns (
            IDisputeGameFactory factory
        ) {
            if (address(factory) != address(0)) {
                return OPWitnessProofType.DisputeGame;
            }
        } catch {}

        try optimismPortal.l2Oracle() returns (IL2OutputOracle oracle) {
            if (address(oracle) != address(0)) {
                return OPWitnessProofType.L2OutputOracle;
            }
        } catch {}

        revert UnknownProofType();
    }

    function getOPProvableBlock(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 minAge,
        uint256 maxAge
    ) public view returns (OPProvableBlock memory result) {
        result.proofType = getProofType(optimismPortal);

        if (result.proofType == OPWitnessProofType.DisputeGame) {
            (
                uint256 disputeGameIndex,
                bytes32 outputRoot,
                ,
                uint256 blockNumber,
                ,

            ) = getLatestRespectedDisputeGame(optimismPortal, minAge, maxAge);

            result.index = disputeGameIndex;
            result.outputRoot = outputRoot;
            result.blockNumber = blockNumber;

            return result;
        } else if (result.proofType == OPWitnessProofType.L2OutputOracle) {
            (
                uint256 index,
                Types.OutputProposal memory output
            ) = getLatestL2Output(optimismPortal, minAge, maxAge);

            result.index = index;
            result.outputRoot = output.outputRoot;
            result.blockNumber = output.l2BlockNumber;

            return result;
        }

        revert UnknownProofType();
    }
}
