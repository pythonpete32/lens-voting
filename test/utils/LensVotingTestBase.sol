// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import { DSTestPlus } from "solmate/src/test/utils/DSTestPlus.sol";
import { DAOMock } from "../mocks/DAOMock.sol";
import { LensVoting } from "../../src/LensVoting.sol";
import { MockFollow } from "../mocks/MockFollow.sol";
import { IFollowNFT } from "@lens/interfaces/IFollowNFT.sol";
import { IDAO } from "@aragon/core/IDAO.sol";

import { VoteOption } from "../../src/lib/Structs.sol";

contract LensVotingTestBase is DSTestPlus {
    // contracts
    DAOMock dao;
    LensVoting lensVoting;
    MockFollow followNFT;

    // vote settings
    uint64 supportRequiredPct = 50e16;
    uint64 participationRequiredPct = 5e16;
    uint64 minDuration = 1 days;

    // user addresses
    address bob = hevm.addr(0xB0B);
    address alice = hevm.addr(0xA11CE);
    address zain = hevm.addr(0x541);
    address random = hevm.addr(0x123);

    function setUp() public {
        dao = new DAOMock(admin);
        lensVoting = new LensVoting();
        followNFT = new MockFollow();
        hevm.deal(alice, 100 ether);
        hevm.deal(bob, 100 ether);
        hevm.deal(zain, 100 ether);
        hevm.label(admin, "admin");
        hevm.label(bob, "bob");
        hevm.label(alice, "alice");
        hevm.label(zain, "zain");
        hevm.label(random, "random");
    }

    // setup function
    function setupVoting() public {
        lensVoting.initialize(
            dao,
            participationRequiredPct,
            supportRequiredPct,
            minDuration,
            IFollowNFT(followNFT)
        );
        followNFT.mint(bob);
        followNFT.mint(alice);
        followNFT.mint(zain);
    }

    // setup function

    function delegateUser(address user) public {
        hevm.prank(user);
        followNFT.delegate(user);
        hevm.roll(block.number + 1);
    }

    // helper functions
    function mockVote() public view returns (IDAO.Action[] memory) {
        IDAO.Action[] memory actions = new IDAO.Action[](1);
        actions[0] = IDAO.Action({ to: random, value: 0, data: "0x00" });
        return actions;
    }

    function createMockVote(address proposer, VoteOption option) public {
        hevm.prank(proposer);
        lensVoting.createVote(
            "0x00",
            mockVote(),
            uint64(block.timestamp),
            uint64(block.timestamp) + minDuration,
            false,
            option
        );
    }
}
