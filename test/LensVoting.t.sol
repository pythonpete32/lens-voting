// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import { LensVotingTestBase } from "./utils/LensVotingTestBase.sol";
import { VoteOption, Vote } from "../src/lib/Structs.sol";

contract LensVotingTest is LensVotingTestBase {
    /* ====================================================================== //
                                    Initialize
    // ====================================================================== */
    function testInitialize() public {
        lensVoting.initialize(dao, 50e16, 5e16, 180, followNFT);
    }

    function testFailInitializeTwice() public {
        lensVoting.initialize(dao, 50e16, 5e16, 180, followNFT);
        lensVoting.initialize(dao, 50e16, 5e16, 180, followNFT);
    }

    /* ====================================================================== //
                                    Vote Creation
    // ====================================================================== */
    function testFailCannotCreateLessThanMinDuration() public {
        setupVoting();
        delegateUser(alice);

        uint64 start = uint64(block.timestamp);
        uint64 end = start + (minDuration - 1);

        hevm.startPrank(alice);
        // hevm.expectRevert(MajorityVotingBase.VoteTimesInvalid.selector)
        lensVoting.createVote("0x00", mockVote(), start, end, false, VoteOption.None);
        hevm.stopPrank();
    }

    function testCreateButNotVote() public {
        setupVoting();
        delegateUser(alice);

        // setup vote
        // uint64 start = uint64(block.timestamp);
        // uint64 end = start + minDuration;
        hevm.startPrank(alice);
        lensVoting.createVote(
            "0x00",
            mockVote(),
            uint64(block.timestamp),
            uint64(block.timestamp) + minDuration,
            false,
            VoteOption.None
        );
        hevm.stopPrank();

        // expect vote to be created
        assertEq(lensVoting.votesLength(), 1);

        // compare the vote to expected values
        Vote memory vote = lensVoting.getVote(0);
    }

    function testCreateAndVote() public {}

    /* ====================================================================== //
                                Casting and execution
    // ====================================================================== */
    function testCannotVoteWithNoPower() public {
        setupVoting();
        hevm.expectRevert(NoVotingPower());
        lensVoting.createVote("0x00", mockVote(), 0, 0, false, VoteOption.None);
    }

    function testShouldIncreaseYesAndEmit() public {}

    function testShouldIncreaseNoAndEmit() public {}

    function testShouldIncreaseAbstainAndEmit() public {}

    function testMultipleVotesShouldNotIncrease() public {}

    function testShouldMakeExecutableIfThresholdReached() public {}

    function testShouldMakeNonExecutableIfThresholdNotReached() public {}

    function testShouldExecuteImmediatelyIfFinalYes() public {}

    function testShouldRevertIfExecutedBeforeThreshold() public {}
}
