// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@eth-optimism/contracts-bedrock/src/dispute/interfaces/IDisputeGameFactory.sol";
import "@eth-optimism/contracts-bedrock/src/dispute/interfaces/IFaultDisputeGame.sol";
import {OPOutputLookup, IOptimismPortalOutputRoot, DisputeGameLookup} from "../src/OPOutputLookup.sol";

// IMPORTANT: Must test on ETH Mainnet fork block 20516888

address constant OPTIMISM_PORTAL_ADDRESS = 0xbEb5Fc579115071764c7423A4f12eDde41f106Ed;

contract DisputeGameLookupTest is Test {
    OPOutputLookup public lookup;
    IDisputeGameFactory public disputeGameFactory;

    function setUp() public {
        lookup = new OPOutputLookup();

        // OP Mainnet DisputeGameFactory
        disputeGameFactory = IDisputeGameFactory(
            0xe5965Ab5962eDc7477C8520243A95517CD252fA9
        );
    }

    function test_getLatestRespectedDisputeGame(uint256 minAge) public {
        vm.assume(minAge <= 7600000);

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

        (
            GameType gameType_,
            Timestamp timestamp_,
            IDisputeGame proxy_
        ) = disputeGameFactory.gameAtIndex(disputeGameIndex);

        assertEq(gameType_.raw(), gameType.raw());
        assertEq(timestamp_.raw(), gameCreationTime);
        assertEq(address(proxy_), address(proxy));

        IFaultDisputeGame faultDisputeGame = IFaultDisputeGame(address(proxy));

        bytes32 outputRoot_ = faultDisputeGame.rootClaim().raw();
        uint256 blockNumber_ = faultDisputeGame.l2BlockNumber();

        assertEq(outputRoot_, outputRoot);
        assertEq(blockNumber_, blockNumber);

        assertLe(gameCreationTime, block.timestamp - minAge);

        // At minAge > 5000000 there are delays in the official dispute game submission
        if (minAge <= 5000000) {
            assertLe(block.timestamp - minAge - gameCreationTime, 10000);
        }
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

    function test_getDisputeGame(uint256 minAge) public {
        vm.assume(minAge <= 7600000);

        (uint256 disputeGameIndex, , , , , ) = lookup
            .getLatestRespectedDisputeGame(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                minAge,
                1000000000000000000
            );

        (
            bytes32 outputRoot,
            GameType gameType,
            uint64 gameCreationTime,
            IDisputeGame proxy
        ) = lookup.getRespectedDisputeGame(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                disputeGameIndex,
                minAge,
                1000000000000000000
            );

        (
            GameType gameType_,
            Timestamp timestamp_,
            IDisputeGame proxy_
        ) = disputeGameFactory.gameAtIndex(disputeGameIndex);

        assertEq(gameType_.raw(), gameType.raw());
        assertEq(timestamp_.raw(), gameCreationTime);
        assertEq(address(proxy_), address(proxy));

        IFaultDisputeGame faultDisputeGame = IFaultDisputeGame(address(proxy));

        bytes32 outputRoot_ = faultDisputeGame.rootClaim().raw();

        assertEq(outputRoot_, outputRoot);

        assertLe(gameCreationTime, block.timestamp - minAge);
    }

    function test_getDisputeGameTooEarly(uint256 minAge) public {
        vm.assume(minAge <= 5000000);

        (uint256 disputeGameIndex, , uint64 gameCreationTime, , , ) = lookup
            .getLatestRespectedDisputeGame(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                minAge,
                1000000000000000000
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                DisputeGameLookup.GameTooEarly.selector,
                disputeGameIndex,
                block.timestamp - gameCreationTime,
                minAge + 10000
            )
        );

        lookup.getRespectedDisputeGame(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            disputeGameIndex,
            minAge + 10000,
            1000000000000000000
        );
    }

    function test_getDisputeGameExpired(uint256 minAge) public {
        vm.assume(minAge > 10000 && minAge <= 5000000);

        (uint256 disputeGameIndex, , uint64 gameCreationTime, , , ) = lookup
            .getLatestRespectedDisputeGame(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                minAge,
                1000000000000000000
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                DisputeGameLookup.GameExpired.selector,
                disputeGameIndex,
                block.timestamp - gameCreationTime,
                minAge - 10000
            )
        );

        lookup.getRespectedDisputeGame(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            disputeGameIndex,
            0,
            minAge - 10000
        );
    }
}
