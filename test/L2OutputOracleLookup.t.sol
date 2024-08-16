// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "@eth-optimism/contracts-bedrock/src/dispute/interfaces/IDisputeGameFactory.sol";
import "@eth-optimism/contracts-bedrock/src/dispute/interfaces/IFaultDisputeGame.sol";
import {OPOutputLookup, IOptimismPortalOutputRoot, L2OutputOracleLookup} from "../src/OPOutputLookup.sol";
import {IL2OutputOracle, IOptimismPortalOutputRoot, Types} from "../src/interfaces/IOptimismPortalOutputRoot.sol";

// Mode Mainnet OptimismPortalProxy
address constant OPTIMISM_PORTAL_ADDRESS = 0x8B34b14c7c7123459Cf3076b8Cb929BE097d0C07;

contract L2OutputOracleLookupTest is Test {
    OPOutputLookup public lookup;
    IL2OutputOracle public oracle;

    function setUp() public {
        lookup = new OPOutputLookup();

        // Mode Mainnet L2OutputOracle
        oracle = IL2OutputOracle(0x4317ba146D4933D889518a3e5E11Fe7a53199b04);
    }

    function test_getLatestL2Output(uint256 minAge) public {
        vm.assume(minAge <= 10000000);

        (uint256 index, Types.OutputProposal memory output) = lookup
            .getLatestL2Output(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                minAge,
                1000000000000000000
            );

        Types.OutputProposal memory output_ = oracle.getL2Output(index);

        assertEq(output_.outputRoot, output.outputRoot);
        assertEq(output_.timestamp, output.timestamp);
        assertEq(output_.l2BlockNumber, output.l2BlockNumber);

        assertLe(output.timestamp, block.timestamp - minAge);
        assertLe(block.timestamp - minAge - output.timestamp, 10000);
    }

    function test_minAgeTooLong() public {
        // In this case, it will revert with an arithmetic underflow error
        // Because either minAge > block.timestamp
        // Or the first output timestamp > maxTimestamp
        // As a result, _findSearchStart return (lo - 1) = 0 - 1
        // Not worth to handle seperately for this rarely used case
        vm.expectRevert();

        lookup.getLatestL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            100000000,
            1000000000000000000
        );
    }

    function test_maxAgeTooShort() public {
        uint256 maxAge = 100;
        uint256 index = oracle.latestOutputIndex();

        Types.OutputProposal memory output_ = oracle.getL2Output(index);

        vm.expectRevert(
            abi.encodeWithSelector(
                L2OutputOracleLookup.OutputExpired.selector,
                index,
                block.timestamp - output_.timestamp,
                maxAge
            )
        );

        lookup.getLatestL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            0,
            maxAge
        );
    }

    function test_rangeTooNarrow() public {
        uint256 minAge = 3900;
        uint256 maxAge = 4000;
        uint256 index = oracle.latestOutputIndex() - 1;

        Types.OutputProposal memory output_ = oracle.getL2Output(index);

        vm.expectRevert(
            abi.encodeWithSelector(
                L2OutputOracleLookup.OutputExpired.selector,
                index,
                block.timestamp - output_.timestamp,
                maxAge
            )
        );

        lookup.getLatestL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            minAge,
            maxAge
        );
    }

    function test_getL2Output(uint256 minAge) public {
        vm.assume(minAge <= 10000000);

        (uint256 index, ) = lookup.getLatestL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            minAge,
            1000000000000000000
        );

        Types.OutputProposal memory output = lookup.getL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            index,
            minAge,
            1000000000000000000
        );

        Types.OutputProposal memory output_ = oracle.getL2Output(index);

        assertEq(output_.outputRoot, output.outputRoot);
        assertEq(output_.timestamp, output.timestamp);
        assertEq(output_.l2BlockNumber, output.l2BlockNumber);

        assertLe(output.timestamp, block.timestamp - minAge);
        assertLe(block.timestamp - minAge - output.timestamp, 10000);
    }

    function test_getL2OutputTooEarly(uint256 minAge) public {
        vm.assume(minAge <= 10000000);

        (uint256 index, Types.OutputProposal memory output) = lookup
            .getLatestL2Output(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                minAge,
                1000000000000000000
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                L2OutputOracleLookup.OutputTooEarly.selector,
                index,
                block.timestamp - output.timestamp,
                minAge + 10000
            )
        );

        lookup.getL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            index,
            minAge + 10000,
            1000000000000000000
        );
    }

    function test_getL2OutputExpired(uint256 minAge) public {
        vm.assume(minAge > 10000 && minAge <= 10000000);

        (uint256 index, Types.OutputProposal memory output) = lookup
            .getLatestL2Output(
                IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
                minAge,
                1000000000000000000
            );

        vm.expectRevert(
            abi.encodeWithSelector(
                L2OutputOracleLookup.OutputExpired.selector,
                index,
                block.timestamp - output.timestamp,
                minAge - 10000
            )
        );

        lookup.getL2Output(
            IOptimismPortalOutputRoot(OPTIMISM_PORTAL_ADDRESS),
            index,
            0,
            minAge - 10000
        );
    }
}
