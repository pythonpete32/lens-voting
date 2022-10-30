// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { FollowNFT } from "@lens/core/FollowNFT.sol";

contract MockFollow is FollowNFT {
    // We create the FollowNFT with the pre-computed HUB address before deploying the hub.
    constructor() FollowNFT(address(0x0000000000000000000000000000000000000001)) {}

    function mint_(address to) public returns (uint256) {
        unchecked {
            uint256 tokenId = ++_tokenIdCounter;
            _mint(to, tokenId);
            return tokenId;
        }
    }
}
