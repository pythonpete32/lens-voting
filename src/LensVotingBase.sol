// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {
    IERC165Upgradeable
} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {
    ERC165Upgradeable
} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PluginUUPSUpgradeable } from "@aragon/core/plugin/PluginUUPSUpgradeable.sol";
import { TimeHelpers } from "@aragon/utils/TimeHelpers.sol";
import { IDAO } from "@aragon/core/IDAO.sol";

import { ILensVoting } from "./interface/ILensVoting.sol";
import { Vote, VoteView, VoteOption } from "./lib/Structs.sol";

/// @title LensVotingBase
/// @notice The abstract implementation of majority voting components.
/// @dev This component implements the `ILensVoting` interface.
abstract contract LensVotingBase is
    ILensVoting,
    Initializable,
    ERC165Upgradeable,
    TimeHelpers,
    PluginUUPSUpgradeable
{
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 internal constant BASE_LENS_VOTING_INTERFACE_ID = type(ILensVoting).interfaceId;

    /// @notice The ID of the permission required to call the `setConfiguration` function.
    bytes32 public constant SET_CONFIGURATION_PERMISSION_ID =
        keccak256("SET_CONFIGURATION_PERMISSION");

    /// @notice The base value being defined to correspond to 100% to calculate and compare percentages despite the lack of floating point arithmetic.
    uint64 public constant PCT_BASE = 10**18; // 0% = 0; 1% = 10^16; 100% = 10^18

    /// @notice A mapping between vote IDs and vote information.
    mapping(uint256 => Vote) public votes;

    /// @notice A mapping between vote IDs user voting options
    mapping(uint256 => mapping(address => VoteOption)) public voters;

    uint64 public supportRequiredPct;
    uint64 public participationRequiredPct;
    uint64 public minDuration;
    uint256 public votesLength;

    /// @notice Initializes the component to be used by inheriting contracts.
    /// @dev This method is required to support [ERC-1822](https://eips.ethereum.org/EIPS/eip-1822).
    /// @param _dao The IDAO interface of the associated DAO.
    /// @param _participationRequiredPct The minimal required participation in percent.
    /// @param _supportRequiredPct The minimal required support in percent.
    /// @param _minDuration The minimal duration of a vote
    function __MajorityVotingBase_init(
        IDAO _dao,
        uint64 _participationRequiredPct,
        uint64 _supportRequiredPct,
        uint64 _minDuration
    ) internal onlyInitializing {
        __PluginUUPSUpgradeable_init(_dao);

        _validateAndSetSettings(_participationRequiredPct, _supportRequiredPct, _minDuration);

        emit ConfigUpdated(_participationRequiredPct, _supportRequiredPct, _minDuration);
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param interfaceId The ID of the interace.
    /// @return bool Returns true if the interface is supported.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, PluginUUPSUpgradeable)
        returns (bool)
    {
        return interfaceId == BASE_LENS_VOTING_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ILensVoting
    function setConfiguration(
        uint64 _participationRequiredPct,
        uint64 _supportRequiredPct,
        uint64 _minDuration
    ) external auth(SET_CONFIGURATION_PERMISSION_ID) {
        _validateAndSetSettings(_participationRequiredPct, _supportRequiredPct, _minDuration);

        emit ConfigUpdated(_participationRequiredPct, _supportRequiredPct, _minDuration);
    }

    /// @inheritdoc ILensVoting
    function createVote(
        bytes calldata _proposalMetadata,
        IDAO.Action[] calldata _actions,
        uint64 _startDate,
        uint64 _endDate,
        bool _executeIfDecided,
        VoteOption _choice
    ) external virtual returns (uint256 voteId);

    /// @inheritdoc ILensVoting
    function vote(
        uint256 _voteId,
        VoteOption _choice,
        bool _executesIfDecided
    ) external {
        if (_choice != VoteOption.None && !_canVote(_voteId, _msgSender()))
            revert VoteCastingForbidden();
        _vote(_voteId, _choice, _msgSender(), _executesIfDecided);
    }

    /// @inheritdoc ILensVoting
    function execute(uint256 _voteId) public {
        if (!_canExecute(_voteId)) revert VoteExecutionForbidden();
        _execute(_voteId);
    }

    /// @inheritdoc ILensVoting
    function getVoteOption(uint256 _voteId, address _voter) public view returns (VoteOption) {
        return voters[_voteId][_voter];
    }

    /// @inheritdoc ILensVoting
    function canVote(uint256 _voteId, address _voter) public returns (bool) {
        return _canVote(_voteId, _voter);
    }

    /// @inheritdoc ILensVoting
    function canExecute(uint256 _voteId) public view returns (bool) {
        return _canExecute(_voteId);
    }

    /// @inheritdoc ILensVoting
    function getVote(uint256 _voteId) public view returns (VoteView memory voteView) {
        //
        Vote memory vote_ = votes[_voteId];

        voteView = VoteView(
            _isVoteOpen(votes[_voteId]),
            vote_.executed,
            vote_.startDate,
            vote_.endDate,
            vote_.snapshotBlock,
            vote_.supportRequiredPct,
            vote_.participationRequiredPct,
            vote_.votingPower,
            vote_.yes,
            vote_.no,
            vote_.abstain,
            vote_.actions
        );
    }

    /// @inheritdoc ILensVoting
    function isVoteOpen(uint256 _voteId) public view returns (bool) {
        return _isVoteOpen(votes[_voteId]);
    }

    /// @notice Internal function to cast a vote. It assumes the queried vote exists.
    /// @param _voteId The ID of the vote.
    /// @param _choice Whether voter abstains, supports or not supports to vote.
    /// @param _executesIfDecided if true, and it's the last vote required, immediately executes a vote.
    function _vote(
        uint256 _voteId,
        VoteOption _choice,
        address _voter,
        bool _executesIfDecided
    ) internal virtual;

    /// @notice Internal function to execute a vote. It assumes the queried vote exists.
    /// @param _voteId The ID of the vote.
    function _execute(uint256 _voteId) internal virtual {
        votes[_voteId].executed = true;

        bytes[] memory execResults = dao.execute(_voteId, votes[_voteId].actions);

        emit VoteExecuted(_voteId, execResults);
    }

    /// @notice Internal function to check if a voter can participate on a vote. It assumes the queried vote exists.
    /// @param _voteId The ID of the vote.
    /// @param _voter the address of the voter to check.
    /// @return True if the given voter can participate a certain vote, false otherwise.
    function _canVote(uint256 _voteId, address _voter) internal virtual returns (bool);

    /// @notice Internal function to check if a vote can be executed. It assumes the queried vote exists.
    /// @param _voteId The ID of the vote.
    /// @return True if the given vote can be executed, false otherwise.
    function _canExecute(uint256 _voteId) internal view virtual returns (bool) {
        Vote storage vote_ = votes[_voteId];

        if (vote_.executed) {
            return false;
        }

        // Voting is already decided
        if (_isValuePct(vote_.yes, vote_.votingPower, vote_.supportRequiredPct)) {
            return true;
        }

        // Vote ended?
        if (_isVoteOpen(vote_)) {
            return false;
        }

        uint256 totalVotes = vote_.yes + vote_.no;

        // Have enough people's stakes participated ? then proceed.
        if (
            !_isValuePct(
                totalVotes + vote_.abstain,
                vote_.votingPower,
                vote_.participationRequiredPct
            )
        ) {
            return false;
        }

        // Has enough support?
        if (!_isValuePct(vote_.yes, totalVotes, vote_.supportRequiredPct)) {
            return false;
        }

        return true;
    }

    /// @notice Internal function to check if a vote is still open.
    /// @param vote_ the vote struct.
    /// @return True if the given vote is open, false otherwise.
    function _isVoteOpen(Vote storage vote_) internal view virtual returns (bool) {
        return
            getTimestamp64() < vote_.endDate &&
            getTimestamp64() >= vote_.startDate &&
            !vote_.executed;
    }

    /// @notice Calculates whether `_value` is more than a percentage `_pct` of `_total`.
    /// @param _value the current value.
    /// @param _total the total value.
    /// @param _pct the required support percentage.
    /// @return returns if the _value is _pct or more percentage of _total.
    function _isValuePct(
        uint256 _value,
        uint256 _total,
        uint256 _pct
    ) internal pure returns (bool) {
        if (_total == 0) {
            return false;
        }

        uint256 computedPct = (_value * PCT_BASE) / _total;
        return computedPct > _pct;
    }

    function _validateAndSetSettings(
        uint64 _participationRequiredPct,
        uint64 _supportRequiredPct,
        uint64 _minDuration
    ) internal virtual {
        if (_supportRequiredPct > PCT_BASE) {
            revert VoteSupportExceeded();
        }

        if (_participationRequiredPct > PCT_BASE) {
            revert VoteParticipationExceeded();
        }

        if (_minDuration == 0) {
            revert VoteDurationZero();
        }

        participationRequiredPct = _participationRequiredPct;
        supportRequiredPct = _supportRequiredPct;
        minDuration = _minDuration;
    }

    /// @notice This empty reserved space is put in place to allow future versions to add new variables without shifting down storage in the inheritance chain (see [OpenZepplins guide about storage gaps](https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps)).
    uint256[47] private __gap;
}
