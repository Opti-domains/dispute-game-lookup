// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IOptimismPortalOutputRoot.sol";

library L2OutputOracleLookup {
    error OutputExpired(uint256 l2OutputIndex, uint256 age, uint256 maxAge);
    error OutputTooEarly(uint256 l2OutputIndex, uint256 age, uint256 minAge);
    error OutputNotFound(uint256 minAge);
    error L2OutputOracleDeprecated();

    function _l2OutputOracle(
        IOptimismPortalOutputRoot optimismPortal
    ) internal view returns (IL2OutputOracle) {
        try optimismPortal.l2Oracle() returns (IL2OutputOracle oracle) {
            if (address(oracle) == address(0)) {
                revert L2OutputOracleDeprecated();
            }

            return oracle;
        } catch {
            revert L2OutputOracleDeprecated();
        }
    }

    function getLatestL2Output(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 minAge,
        uint256 maxAge
    ) public view returns (uint256 index, Types.OutputProposal memory) {
        IL2OutputOracle oracle = _l2OutputOracle(optimismPortal);
        uint256 length = oracle.latestOutputIndex();

        uint256 maxTimestamp = block.timestamp - minAge;
        uint256 minTimestamp = block.timestamp - maxAge;

        // Perform a reverse linear search since we only use recent output most of the time.
        for (uint256 i = length; i >= 0 && i <= length; ) {
            Types.OutputProposal memory output = oracle.getL2Output(i);

            if (output.timestamp <= maxTimestamp) {
                if (maxAge == 0 || output.timestamp >= minTimestamp) {
                    return (i, output);
                } else {
                    revert OutputExpired(
                        i,
                        block.timestamp - output.timestamp,
                        maxAge
                    );
                }
            }

            unchecked {
                i--;
            }
        }

        revert OutputNotFound(minAge);
    }

    function getL2Output(
        IOptimismPortalOutputRoot optimismPortal,
        uint256 index,
        uint256 minAge,
        uint256 maxAge
    ) public view returns (Types.OutputProposal memory) {
        IL2OutputOracle oracle = _l2OutputOracle(optimismPortal);
        Types.OutputProposal memory output = oracle.getL2Output(index);

        // Wait for challenger to challenge the output
        if (block.timestamp - output.timestamp < minAge) {
            revert OutputTooEarly(
                index,
                block.timestamp - output.timestamp,
                minAge
            );
        }

        // Reject output that has been expired
        if (maxAge > 0 && block.timestamp - output.timestamp > maxAge) {
            revert OutputExpired(
                index,
                block.timestamp - output.timestamp,
                maxAge
            );
        }

        return output;
    }
}
