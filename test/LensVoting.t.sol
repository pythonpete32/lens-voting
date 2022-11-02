// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import { LensVotingTestBase } from "./utils/LensVotingTestBase.sol";
import { Vote, VoteView, VoteOption } from "../src/lib/Structs.sol";
import { ILensVoting } from "../src/interface/ILensVoting.sol";
import { LensVoting } from "../src/LensVoting.sol";

contract LensVotingTest is LensVotingTestBase {
    event VoteDirection(uint256 option);

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
    function testCannotCreateLessThanMinDuration() public {
        setupVoting();
        delegateUser(alice);

        uint64 start = uint64(block.timestamp);
        uint64 end = start + (minDuration - 1);

        hevm.startPrank(alice);
        hevm.expectRevert(ILensVoting.VoteTimesInvalid.selector);
        lensVoting.createVote("0x00", mockVote(), start, end, false, VoteOption.None);
        hevm.stopPrank();
    }

    function testCreateButNotVote() public {
        setupVoting();
        delegateUser(alice);
        createMockVote(alice, VoteOption.None);

        // expect vote to be created
        assertEq(lensVoting.votesLength(), 1);

        VoteView memory vote = lensVoting.getVote(0);

        assertTrue(vote.open);
        assertFalse(vote.executed);
        assertEq(vote.supportRequired, 50e16);
        assertEq(vote.participationRequired, 5e16);
        assertEq(vote.snapshotBlock, block.number - 1);
        assertEq(vote.votingPower, 1);
        assertEq(vote.yes, 0);
        assertEq(vote.no, 0);
        assertEq(vote.abstain, 0);

        assertEq(vote.startDate + minDuration, vote.endDate);
        assertEq(vote.actions.length, 1);
        assertEq(vote.actions[0].to, random);
        assertEq(vote.actions[0].value, 0);
        assertEq0(vote.actions[0].data, "0x00");
    }

    function testCreateAndVote() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);
        delegateUser(zain);
        createMockVote(alice, VoteOption.Yes);

        // expect vote to be created
        assertEq(lensVoting.votesLength(), 1);

        VoteView memory vote = lensVoting.getVote(0);

        assertTrue(vote.open);
        assertFalse(vote.executed);
        assertEq(vote.votingPower, 3);
        assertEq(vote.yes, 1);
        assertEq(vote.no, 0);
        assertEq(vote.abstain, 0);
    }

    /* ====================================================================== //
                                Casting and execution
    // ====================================================================== */
    function testCannotVoteWithNoPower() public {
        setupVoting();
        hevm.expectRevert(LensVoting.NoVotingPower.selector);
        lensVoting.createVote("0x00", mockVote(), 0, 0, false, VoteOption.None);
    }

    function testShouldIncreaseYesNoAbstainAnd() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);
        delegateUser(zain);

        createMockVote(alice, VoteOption.Yes);
        hevm.prank(bob);
        lensVoting.vote(0, VoteOption.No, false);
        hevm.prank(zain);
        lensVoting.vote(0, VoteOption.Abstain, false);

        VoteView memory vote = lensVoting.getVote(0);

        assertTrue(vote.open);
        assertFalse(vote.executed);
        assertEq(vote.votingPower, 3);
        assertEq(vote.yes, 1);
        assertEq(vote.no, 1);
        assertEq(vote.abstain, 1);
    }

    function testMultipleVotesShouldNotIncrease() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);
        delegateUser(zain);

        createMockVote(alice, VoteOption.Yes);
        VoteView memory vote = lensVoting.getVote(0);
        assertEq(vote.yes, 1);

        hevm.prank(alice);
        lensVoting.vote(0, VoteOption.Yes, false);
        vote = lensVoting.getVote(0);
        assertEq(vote.yes, 1);

        hevm.startPrank(bob);
        assertEq(vote.no, 0);
        lensVoting.vote(0, VoteOption.No, false);
        vote = lensVoting.getVote(0);
        assertEq(vote.no, 1);
        lensVoting.vote(0, VoteOption.No, false);
        vote = lensVoting.getVote(0);
        assertEq(vote.no, 1);
        hevm.stopPrank();

        hevm.startPrank(zain);
        assertEq(vote.abstain, 0);
        lensVoting.vote(0, VoteOption.Abstain, false);
        vote = lensVoting.getVote(0);
        assertEq(vote.abstain, 1);
        lensVoting.vote(0, VoteOption.Abstain, false);
        vote = lensVoting.getVote(0);
        assertEq(vote.abstain, 1);
    }

    function testShouldMakeExecutableIfThresholdReached() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);
        delegateUser(zain);

        createMockVote(alice, VoteOption.Yes);
        hevm.prank(bob);
        lensVoting.vote(0, VoteOption.No, false);

        VoteView memory vote = lensVoting.getVote(0);

        assertEq(vote.votingPower, 3);
        assertEq(vote.yes, 1);
        assertEq(vote.no, 1);

        assertFalse(lensVoting.canExecute(0));

        hevm.prank(zain);
        lensVoting.vote(0, VoteOption.Yes, false);
        assertTrue(lensVoting.canExecute(0));
    }

    function testShouldBeNonExecutableIfThresholdNotReached() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);
        delegateUser(zain);

        createMockVote(alice, VoteOption.Yes);
        hevm.prank(bob);
        lensVoting.vote(0, VoteOption.No, false);

        VoteView memory vote = lensVoting.getVote(0);

        assertEq(vote.votingPower, 3);
        assertEq(vote.yes, 1);
        assertEq(vote.no, 1);

        assertFalse(lensVoting.canExecute(0));

        hevm.prank(zain);
        lensVoting.vote(0, VoteOption.Abstain, false);
        assertFalse(lensVoting.canExecute(0));
    }

    function testShouldExecuteImmediatelyIfFinalYes() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);
        delegateUser(zain);

        createMockVote(alice, VoteOption.Yes);

        VoteView memory vote = lensVoting.getVote(0);
        assertTrue(vote.open);
        assertFalse(vote.executed);

        hevm.prank(bob);
        lensVoting.vote(0, VoteOption.Yes, true);

        vote = lensVoting.getVote(0);

        assertFalse(vote.open);
        assertTrue(vote.executed);
    }

    function testShouldRevertIfExecutedBeforeThreshold() public {
        setupVoting();
        delegateUser(alice);
        delegateUser(bob);

        createMockVote(alice, VoteOption.Yes);

        hevm.startPrank(bob);
        hevm.expectRevert(ILensVoting.VoteExecutionForbidden.selector);
        lensVoting.execute(0);
        hevm.stopPrank();
    }
}
