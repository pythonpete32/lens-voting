// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { IDAO } from "@aragon/core/IDAO.sol";

enum VoteOption {
    None,
    Abstain,
    Yes,
    No
}

struct Vote {
    bool executed;
    uint64 startDate;
    uint64 endDate;
    uint64 snapshotBlock;
    uint64 supportRequiredPct;
    uint64 participationRequiredPct;
    uint256 yes;
    uint256 no;
    uint256 abstain;
    uint256 votingPower;
    IDAO.Action[] actions;
}

struct VoteView {
        bool open;
        bool executed;
        uint64 startDate;
        uint64 endDate;
        uint64 snapshotBlock;
        uint64 supportRequired;
        uint64 participationRequired;
        uint256 votingPower;
        uint256 yes;
        uint256 no;
        uint256 abstain;
        IDAO.Action[] actions;
}
