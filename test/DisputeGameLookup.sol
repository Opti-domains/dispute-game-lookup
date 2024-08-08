// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@eth-optimism/contracts-bedrock/src/dispute/interfaces/IDisputeGameFactory.sol";
import "@eth-optimism/contracts-bedrock/src/dispute/interfaces/IFaultDisputeGame.sol";
import {OPOutputLookup, IOptimismPortalOutputRoot, DisputeGameLookup} from "../src/OPOutputLookup.sol";

address constant OPTIMISM_PORTAL_ADDRESS = 0xbEb5Fc579115071764c7423A4f12eDde41f106Ed;

contract DisputeGameLookupTest is Test {
    OPOutputLookup public lookup;
    IDisputeGameFactory public disputeGameFactory;

    function setUp() public {
        lookup = new OPOutputLookup();

        // OP Mainnet DisputeGameFactory
        disputeGameFactory = IDisputeGameFactory(0xe5965Ab5962eDc7477C8520243A95517CD252fA9);
    }

    function test_getLatestRespectedDisputeGame(uint256 minAge) public {
        vm.assume(minAge < 7000);
        
        (
            uint256 disputeGameIndex,
            bytes32 outputRoot,
            uint64 gameCreationTime,
            uint256 blockNumber,
            IDisputeGame proxy,
            GameType gameType
        ) = lookup.getLatestRespectedDisputeGame(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            minAge,
            1000000000000000000
        );

        (GameType gameType_, Timestamp timestamp_, IDisputeGame proxy_) = disputeGameFactory.gameAtIndex(disputeGameIndex);

        assertEq(gameType_.raw(), gameType.raw());
        assertEq(timestamp_.raw(), gameCreationTime);
        assertEq(address(proxy_), address(proxy));

        IFaultDisputeGame faultDisputeGame = IFaultDisputeGame(address(proxy));

        bytes32 outputRoot_ = faultDisputeGame.rootClaim().raw();
        uint256 blockNumber_ = faultDisputeGame.l2BlockNumber();

        assertEq(outputRoot_, outputRoot);
        assertEq(blockNumber_, blockNumber);

        assertLe(gameCreationTime, block.timestamp - minAge);
        assertLe(block.timestamp - minAge - gameCreationTime, 3700);
    }

    function test_minAgeTooLong() public {
        // In this case, it will revert with an arithmetic underflow error
        // Because either minAge > block.timestamp
        // Or the first dispute game timestamp > maxTimestamp
        // As a result, _findSearchStart return (lo - 1) = 0 - 1
        vm.expectRevert();

        lookup.getLatestRespectedDisputeGame(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            10000000,
            1000000000000000000
        );
    }

    function test_maxAgeTooShort() public {
        uint256 maxAge = 100;
        uint256 disputeGameIndex = disputeGameFactory.gameCount() - 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                DisputeGameLookup.GameExpired.selector,
                disputeGameIndex,
                block.timestamp - maxAge,
                maxAge
            )
        );

        lookup.getLatestRespectedDisputeGame(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            0,
            maxAge
        );
    }

    function test_rangeTooNarrow() public {
        uint256 minAge = 3900;
        uint256 maxAge = 4000;
        uint256 disputeGameIndex = disputeGameFactory.gameCount() - 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                DisputeGameLookup.GameExpired.selector,
                disputeGameIndex,
                block.timestamp - maxAge,
                maxAge
            )
        );

        lookup.getLatestRespectedDisputeGame(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            minAge,
            maxAge
        );
    }
}
