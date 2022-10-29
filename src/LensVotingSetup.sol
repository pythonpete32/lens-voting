// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IDAO } from "@aragon/core/IDAO.sol";
import { DAO } from "@aragon/core/DAO.sol";
import { PermissionLib } from "@aragon/core/permission/PermissionLib.sol";
import { PluginSetup, IPluginSetup } from "@aragon/plugin/PluginSetup.sol";

import { IFollowNFT } from "./interface/IFollowNFT.sol";
import { LensVoting } from "./LensVoting.sol";

/// @title LensVotingSetup
/// @notice The setup contract of the `LensVoting` plugin.
contract LensVotingSetup is PluginSetup {
    using Address for address;
    using Clones for address;
    using ERC165Checker for address;

    /// @notice The address of the `LensVoting` base contract.
    LensVoting private immutable lensVotingBase;

    /// @notice The address zero to be used as oracle address for permissions.
    address private constant NO_ORACLE = address(0);

    struct TokenSettings {
        address addr;
        string name;
        string symbol;
    }

    /// @notice Thrown if token address is passed which is not a token.
    /// @param token The token address
    error TokenNotContract(address token);

    /// @notice Thrown if token address is not IFollowNFT.
    /// @param token The token address
    error TokenNotIFollow(address token);

    /// @notice Thrown if passed helpers array is of worng length.
    /// @param length The array length of passed helpers.
    error WrongHelpersArrayLength(uint256 length);

    /// @notice The contract constructor, that deployes the bases.
    constructor() {
        lensVotingBase = new LensVoting();
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallationDataABI() external pure returns (string memory) {
        return
            "(uint64 participationRequiredPct, uint64 supportRequiredPct, uint64 minDuration, tuple(address addr, string name, string symbol) tokenSettings)";
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(address _dao, bytes memory _data)
        external
        returns (
            address plugin,
            address[] memory helpers,
            PermissionLib.ItemMultiTarget[] memory permissions
        )
    {
        IDAO dao = IDAO(_dao);

        // Decode `_data` to extract the params needed for deploying and initializing `LensVoting` plugin,
        // and the required helpers
        (
            uint64 participationRequiredPct,
            uint64 supportRequiredPct,
            uint64 minDuration,
            TokenSettings memory tokenSettings
        ) = abi.decode(_data, (uint64, uint64, uint64, TokenSettings));

        address token = tokenSettings.addr;

        // Prepare helpers.
        helpers = new address[](1);

        if (!token.isContract()) {
            revert TokenNotContract(token);
        }

        if (!_isFollowNFT(token)) {
            revert TokenNotIFollow(token);
        }

        // Prepare and deploy plugin proxy.
        plugin = createERC1967Proxy(
            address(lensVotingBase),
            abi.encodeWithSelector(
                LensVoting.initialize.selector,
                dao,
                participationRequiredPct,
                supportRequiredPct,
                minDuration,
                token
            )
        );

        // Prepare permissions
        permissions = new PermissionLib.ItemMultiTarget[](3);

        // Set plugin permissions to be granted.
        // Grant the list of prmissions of the plugin to the DAO.
        permissions[0] = PermissionLib.ItemMultiTarget(
            PermissionLib.Operation.Grant,
            plugin,
            _dao,
            NO_ORACLE,
            lensVotingBase.SET_CONFIGURATION_PERMISSION_ID()
        );

        permissions[1] = PermissionLib.ItemMultiTarget(
            PermissionLib.Operation.Grant,
            plugin,
            _dao,
            NO_ORACLE,
            lensVotingBase.UPGRADE_PLUGIN_PERMISSION_ID()
        );

        // Grant `EXECUTE_PERMISSION` of the DAO to the plugin.
        permissions[2] = PermissionLib.ItemMultiTarget(
            PermissionLib.Operation.Grant,
            _dao,
            plugin,
            NO_ORACLE,
            DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        );
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallationDataABI() external pure returns (string memory) {
        return "";
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        address _plugin,
        address[] calldata _helpers,
        bytes calldata
    ) external view returns (PermissionLib.ItemMultiTarget[] memory permissions) {
        // Prepare permissions.
        uint256 helperLength = _helpers.length;
        if (helperLength != 1) {
            revert WrongHelpersArrayLength({ length: helperLength });
        }
        permissions = new PermissionLib.ItemMultiTarget[](3);

        // Set permissions to be Revoked.
        permissions[0] = PermissionLib.ItemMultiTarget(
            PermissionLib.Operation.Revoke,
            _plugin,
            _dao,
            NO_ORACLE,
            lensVotingBase.SET_CONFIGURATION_PERMISSION_ID()
        );

        permissions[1] = PermissionLib.ItemMultiTarget(
            PermissionLib.Operation.Revoke,
            _plugin,
            _dao,
            NO_ORACLE,
            lensVotingBase.UPGRADE_PLUGIN_PERMISSION_ID()
        );

        permissions[2] = PermissionLib.ItemMultiTarget(
            PermissionLib.Operation.Revoke,
            _dao,
            _plugin,
            NO_ORACLE,
            DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        );
    }

    /// @inheritdoc IPluginSetup
    function getImplementationAddress() external view virtual override returns (address) {
        return address(lensVotingBase);
    }

    /// @notice unsatisfiably determines if contract is FollowNFT..
    /// @dev it's important to check first whether token is a contract.
    /// @param token address
    function _isFollowNFT(address token) private view returns (bool) {
        (bool success, ) = token.staticcall(
            abi.encodeWithSelector(IFollowNFT.getPowerByBlockNumber.selector, address(this))
        );
        return success;
    }
}
