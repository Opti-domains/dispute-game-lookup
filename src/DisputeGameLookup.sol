// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/optimism/IFaultDisputeGame.sol";
import "./interfaces/IOptimismPortalOutputRoot.sol";

library DisputeGameLookup {
    error GameTypeMismatch(
        uint256 disputeGameIndex,
        GameType expected,
        GameType actual
    );
    error GameChallenged(uint256 disputeGameIndex);
    error GameTooEarly(uint256 disputeGameIndex, uint256 age, uint256 minAge);
    error GameExpired(uint256 disputeGameIndex, uint256 age, uint256 maxAge);
    error GameNotFound(uint256 minAge);
    error DisputeGameNotEnabled();

    function _disputeGameFactory(IOptimismPortalOutputRoot optimismPortal) internal view returns(IDisputeGameFactory) {
        try optimismPortal.disputeGameFactory() returns (IDisputeGameFactory factory) {
            if (address(factory) == address(0)) {
                revert DisputeGameNotEnabled();
            }

            return factory;
        } catch {
            revert DisputeGameNotEnabled();
        }
    }

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
        IDisputeGameFactory disputeGameFactory = _disputeGameFactory(optimismPortal);

        // Get dispute game at index
        Timestamp gameCreationTimeRaw;
        (gameType, gameCreationTimeRaw, proxy) = disputeGameFactory.gameAtIndex(
            index
        );
        outputRoot = proxy.rootClaim().raw();

        // Unwrap gameCreationTime to uint64
        gameCreationTime = gameCreationTimeRaw.raw();

        // Wait for challenger to challenge the dispute game
        if (block.timestamp - gameCreationTime < minAge) {
            revert GameTooEarly(
                index,
                block.timestamp - gameCreationTime,
                minAge
            );
        }

        // Reject dispute game that has been expired
        if (maxAge > 0 && block.timestamp - gameCreationTime > maxAge) {
            revert GameExpired(
                index,
                block.timestamp - gameCreationTime,
                maxAge
            );
        }

        // Revert if the game is challenged
        if (proxy.status() == GameStatus.CHALLENGER_WINS) {
            revert GameChallenged(index);
        }
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
        // Get gameType used for L2 withdrawal
        GameType respectedGameType = optimismPortal.respectedGameType();

        // Get dispute game output and game type
        (outputRoot, gameType, gameCreationTime, proxy) = getDisputeGame(
            optimismPortal,
            index,
            minAge,
            maxAge
        );

        // Revert if gameType is not the one used for L2 withdrawal
        if (gameType.raw() != respectedGameType.raw()) {
            revert GameTypeMismatch(index, respectedGameType, gameType);
        }
    }

    function _findSearchBound(
        IDisputeGameFactory disputeGameFactory,
        uint256 maxTimestamp
    ) internal view returns (uint256 lo, uint256 hi) {
        uint256 gameCount = disputeGameFactory.gameCount();

        // Find binary search bound
        uint256 window = 1;
        while (window <= gameCount) {
            (, Timestamp _timestampRaw, ) = disputeGameFactory.gameAtIndex(
                gameCount - window
            );

            // Unwrap gameCreationTime to uint64
            uint64 _timestamp = _timestampRaw.raw();

            if (_timestamp <= maxTimestamp) {
                return (gameCount - window, gameCount - (window >> 1) - 1);
            }

            window <<= 1;
        }

        // In case search bound has expanded larger than the total dispute game
        {
            (, Timestamp _timestampRaw, ) = disputeGameFactory.gameAtIndex(0);

            // Unwrap gameCreationTime to uint64
            uint64 _timestamp = _timestampRaw.raw();

            if (_timestamp > maxTimestamp) {
                revert GameNotFound(block.timestamp - maxTimestamp);
            }

            return (0, gameCount - (window >> 1) - 1);
        }
    }

    function _findSearchStart(
        IDisputeGameFactory disputeGameFactory,
        uint256 maxTimestamp
    ) internal view returns (uint256) {
        (uint256 lo, uint256 hi) = _findSearchBound(
            disputeGameFactory,
            maxTimestamp
        );

        while (lo <= hi) {
            uint256 mid = (lo + hi) / 2;

            (, Timestamp _timestampRaw, ) = disputeGameFactory.gameAtIndex(mid);

            // Unwrap gameCreationTime to uint64
            uint64 _timestamp = _timestampRaw.raw();

            if (_timestamp <= maxTimestamp) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }

        return hi;
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
        uint256 maxTimestamp = block.timestamp - minAge;

        IDisputeGameFactory disputeGameFactory = _disputeGameFactory(optimismPortal);

        uint256 start = _findSearchStart(disputeGameFactory, maxTimestamp);

        IDisputeGameFactory.GameSearchResult[] memory games = disputeGameFactory
            .findLatestGames(gameType, start, 1);

        if (games.length == 0) {
            revert GameNotFound(minAge);
        }

        disputeGameIndex = games[0].index;
        outputRoot = games[0].rootClaim.raw();
        gameCreationTime = games[0].timestamp.raw();

        if (maxAge > 0 && gameCreationTime < block.timestamp - maxAge) {
            revert GameExpired(disputeGameIndex, block.timestamp - maxAge, maxAge);
        }

        (, , proxy) = disputeGameFactory.gameAtIndex(disputeGameIndex);

        try IFaultDisputeGame(address(proxy)).l2BlockNumber() returns (
            uint256 l2BlockNumber
        ) {
            blockNumber = l2BlockNumber;
        } catch {}
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
        // Get gameType used for L2 withdrawal
        gameType = optimismPortal.respectedGameType();

        (
            disputeGameIndex,
            outputRoot,
            gameCreationTime,
            blockNumber,
            proxy
        ) = getLatestDisputeGame(optimismPortal, gameType, minAge, maxAge);
    }
}
