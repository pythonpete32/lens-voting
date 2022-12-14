// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import { VoteOption } from "../lib/Structs.sol";
import { VoteView } from "../lib/Structs.sol";
import { IDAO } from "@aragon/core/IDAO.sol";

/// @title ILensVoting
/// @notice The interface for lens voting contracts.
interface ILensVoting {
    /// @notice Emitted when a vote is created.
    /// @param voteId  The ID of the vote.
    /// @param creator  The creator of the vote.
    /// @param metadata The IPFS hash pointing to the proposal metadata.
    event VoteCreated(uint256 indexed voteId, address indexed creator, bytes metadata);

    /// @notice Emitted when a vote is casted by a voter.
    /// @param voteId The ID of the vote.
    /// @param voter The voter casting the vote.
    /// @param choice The vote option chosen.
    /// @param voteWeight The weight of the casted vote.
    event VoteCast(uint256 indexed voteId, address indexed voter, uint8 choice, uint256 voteWeight);

    /// @notice Emitted when a vote is executed.
    /// @param voteId The ID of the vote.
    /// @param execResults The bytes array resulting from the vote execution in the associated DAO.
    event VoteExecuted(uint256 indexed voteId, bytes[] execResults);

    /// @notice Emitted when the vote configuration is updated.
    /// @param participationRequiredPct The required participation in percent.
    /// @param supportRequiredPct The required support in percent.
    /// @param minDuration The minimal duration of a vote.
    event ConfigUpdated(
        uint64 participationRequiredPct,
        uint64 supportRequiredPct,
        uint64 minDuration
    );

    /// @notice Thrown if the maximal possible support is exceeded.
    error VoteSupportExceeded();

    /// @notice Thrown if the maximal possible participation is exceeded.
    error VoteParticipationExceeded();

    /// @notice Thrown if the selected vote times are not allowed.
    error VoteTimesInvalid();

    /// @notice Thrown if the selected vote duration is zero
    error VoteDurationZero();

    /// @notice Thrown if a voter is not allowed to cast a vote.
    error VoteCastingForbidden();

    /// @notice Thrown if the vote execution is forbidden
    error VoteExecutionForbidden();

    /// @notice Sets the vote configuration.
    /// @param _participationRequiredPct The required participation in percent.
    /// @param _supportRequiredPct The required support in percent.
    /// @param _minDuration The minimal duration of a vote.
    function setConfiguration(
        uint64 _participationRequiredPct,
        uint64 _supportRequiredPct,
        uint64 _minDuration
    ) external;

    /// @notice Creates a new vote.
    /// @param _proposalMetadata The IPFS hash pointing to the proposal metadata.
    /// @param _actions The actions that will be executed after vote passes.
    /// @param _startDate The start date of the vote. If 0, uses current timestamp.
    /// @param _endDate The end date of the vote. If 0, uses `_start` + `minDuration`.
    /// @param _executeIfDecided An option to enable automatic execution on the last required vote.
    /// @param _choice The vote choice to cast on creation.
    /// @return voteId The ID of the vote.
    function createVote(
        bytes calldata _proposalMetadata,
        IDAO.Action[] calldata _actions,
        uint64 _startDate,
        uint64 _endDate,
        bool _executeIfDecided,
        VoteOption _choice
    ) external returns (uint256 voteId);

    /// @notice Votes for a vote option and optionally executes the vote.
    /// @dev `[outcome = 1 = abstain], [outcome = 2 = supports], [outcome = 3 = not supports].
    /// @param _voteId The ID of the vote.
    /// @param  _choice Whether voter abstains, supports or not supports to vote.
    /// @param _executesIfDecided Whether the vote should execute its action if it becomes decided.
    function vote(
        uint256 _voteId,
        VoteOption _choice,
        bool _executesIfDecided
    ) external;

    /// @notice Internal function to check if a voter can participate on a vote. It assumes the queried vote exists.
    /// @param _voteId the vote Id.
    /// @param _voter the address of the voter to check.
    /// @return bool Returns true if the voter is allowed to vote.
    function canVote(uint256 _voteId, address _voter) external returns (bool);

    /// @notice Method to execute a vote if allowed to.
    /// @param _voteId The ID of the vote to execute.
    function execute(uint256 _voteId) external;

    /// @notice Checks if a vote is allowed to execute.
    /// @param _voteId The ID of the vote to execute.
    function canExecute(uint256 _voteId) external view returns (bool);

    /// @notice Returns the state of a voter for a given vote by its ID.
    /// @param _voteId The ID of the vote.
    /// @return VoteOption of the requested voter for a certain vote.
    function getVoteOption(uint256 _voteId, address _voter) external view returns (VoteOption);

    /// @notice Returns the vote data of a vote by its ID.
    /// @param _voteId The ID of the vote.
    /// @return VoteView The vote data.
    function getVote(uint256 _voteId) external view returns (VoteView memory);

    /// @notice Returns true if vote is open
    /// @param _voteId The ID of the vote.
    /// @return bool True if vote is open.
    function isVoteOpen(uint256 _voteId) external view returns (bool);
}
