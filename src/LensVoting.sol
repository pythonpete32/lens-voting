// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import { IFollowNFT } from "@lens/interfaces/IFollowNFT.sol";
import { IDAO } from "@aragon/core/IDAO.sol";

import { LensVotingBase } from "./LensVotingBase.sol";
import { ILensVoting } from "./interface/ILensVoting.sol";
import { Vote, VoteOption } from "./lib/Structs.sol";

/// @title LensVoting
/// @notice The majority voting implementation using an Lens Follow NFT token.
/// @dev This contract inherits from `LensVotingBase` and implements the `ILensVoting` interface.
contract LensVoting is LensVotingBase {
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 internal constant LENS_VOTING_INTERFACE_ID =
        this.getVotingToken.selector ^ this.initialize.selector;

    /// @notice An [IFollowNFT](https://docs.lens.xyz/docs/built-in-governance) compatible contract referencing the token being used for voting.
    IFollowNFT private votingToken;

    /// @notice Thrown if the voting power is zero
    error NoVotingPower();

    /// @notice Initializes the component.
    /// @dev This method is required to support [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822).
    /// @param _dao The IDAO interface of the associated DAO.
    /// @param _participationRequiredPct The minimal required participation in percent.
    /// @param _supportRequiredPct The minimal required support in percent.
    /// @param _minDuration The minimal duration of a vote.
    /// @param _token The [IFollowNFT](https://docs.lens.xyz/docs/built-in-governance) token used for voting.
    function initialize(
        IDAO _dao,
        uint64 _participationRequiredPct,
        uint64 _supportRequiredPct,
        uint64 _minDuration,
        IFollowNFT _token
    ) public initializer {
        __MajorityVotingBase_init(
            _dao,
            _participationRequiredPct,
            _supportRequiredPct,
            _minDuration
        );

        votingToken = _token;
    }

    /// @notice adds a IERC165 to check whether contract supports LENS_VOTING_INTERFACE_ID or not.
    /// @dev See {ERC165Upgradeable-supportsInterface}.
    /// @return bool whether it supports the IERC165 or LENS_VOTING_INTERFACE_ID
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == LENS_VOTING_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /// @notice getter function for the voting token.
    /// @dev public function also useful for registering interfaceId and for distinguishing from majority voting interface.
    /// @return IFollowNFT the token used for voting.
    function getVotingToken() public view returns (IFollowNFT) {
        return votingToken;
    }

    /// @inheritdoc ILensVoting
    function createVote(
        bytes calldata _proposalMetadata,
        IDAO.Action[] calldata _actions,
        uint64 _startDate,
        uint64 _endDate,
        bool _executeIfDecided,
        VoteOption _choice
    ) external override returns (uint256 voteId) {
        uint64 snapshotBlock = getBlockNumber64() - 1;

        uint256 votingPower = votingToken.getDelegatedSupplyByBlockNumber(snapshotBlock);
        if (votingPower == 0) revert NoVotingPower();

        voteId = votesLength++;

        // Calculate the start and end time of the vote
        uint64 currentTimestamp = getTimestamp64();

        if (_startDate == 0) _startDate = currentTimestamp;
        if (_endDate == 0) _endDate = _startDate + minDuration;

        if (_endDate - _startDate < minDuration || _startDate < currentTimestamp)
            revert VoteTimesInvalid();

        // Create the vote
        Vote storage vote_ = votes[voteId];
        vote_.startDate = _startDate;
        vote_.endDate = _endDate;
        vote_.supportRequiredPct = supportRequiredPct;
        vote_.participationRequiredPct = participationRequiredPct;
        vote_.votingPower = votingPower;
        vote_.snapshotBlock = snapshotBlock;

        unchecked {
            for (uint256 i = 0; i < _actions.length; i++) {
                vote_.actions.push(_actions[i]);
            }
        }

        emit VoteCreated(voteId, _msgSender(), _proposalMetadata);

        if (_choice != VoteOption.None && canVote(voteId, _msgSender())) {
            _vote(voteId, _choice, _msgSender(), _executeIfDecided);
        }
    }

    /// @inheritdoc LensVotingBase
    function _vote(
        uint256 _voteId,
        VoteOption _choice,
        address _voter,
        bool _executesIfDecided
    ) internal override {
        Vote storage vote_ = votes[_voteId];

        // This could re-enter, though we can assume the governance token is not malicious
        uint256 voterStake = votingToken.getPowerByBlockNumber(_voter, vote_.snapshotBlock);
        VoteOption state = voters[_voteId][_voter];

        // If voter had previously voted, decrease count
        if (state == VoteOption.Yes) {
            vote_.yes = vote_.yes - voterStake;
        } else if (state == VoteOption.No) {
            vote_.no = vote_.no - voterStake;
        } else if (state == VoteOption.Abstain) {
            vote_.abstain = vote_.abstain - voterStake;
        }

        // write the updated/new vote for the voter.
        if (_choice == VoteOption.Yes) {
            vote_.yes = vote_.yes + voterStake;
        } else if (_choice == VoteOption.No) {
            vote_.no = vote_.no + voterStake;
        } else if (_choice == VoteOption.Abstain) {
            vote_.abstain = vote_.abstain + voterStake;
        }

        voters[_voteId][_voter] = _choice;

        emit VoteCast(_voteId, _voter, uint8(_choice), voterStake);

        if (_executesIfDecided && _canExecute(_voteId)) {
            _execute(_voteId);
        }
    }

    /// @inheritdoc LensVotingBase
    function _canVote(uint256 _voteId, address _voter) internal override returns (bool) {
        Vote storage vote_ = votes[_voteId];
        return
            _isVoteOpen(vote_) &&
            votingToken.getPowerByBlockNumber(_voter, vote_.snapshotBlock) > 0;
    }

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[49] private __gap;
}
