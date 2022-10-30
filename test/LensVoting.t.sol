pragma solidity 0.8.10;

import { DSTestPlus } from "solmate/src/test/utils/DSTestPlus.sol";
import { DAOMock } from "./mocks/DAOMock.sol";
import { LensVoting } from "../src/LensVoting.sol";
import { MockFollow } from "./mocks/MockFollow.sol";

contract LensVotingTest is DSTestPlus {
    // user addresses
    address admin = hevm.addr(0xB055);
    address bob = hevm.addr(0xB0B);
    address alice = hevm.addr(0xA11CE);

    // contracts
    DAOMock dao;
    LensVoting lensVoting;
    MockFollow followNFT;

    function setUp() public {
        dao = new DAOMock(admin);
        lensVoting = new LensVoting();
        followNFT = new MockFollow();
    }

    function testInitialize() public {
        lensVoting.initialize(dao, 50e16, 5e16, 180, followNFT);
    }

    function testFailInitializeTwice() public {
        lensVoting.initialize(dao, 50e16, 5e16, 180, followNFT);
        lensVoting.initialize(dao, 50e16, 5e16, 180, followNFT);
    }
}
