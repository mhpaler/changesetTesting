// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interfaces/IETSTarget.sol";
import "./interfaces/IETSEnrichTarget.sol";
import "./interfaces/IETSAccessControls.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ETSEnrichTarget
 * @author Ethereum Tag Service <team@ets.xyz>
 *
 * @notice Contract that handles the enrichment of Target metadata using off-chain APIs.
 *
 * In order to keep the on-chain recording of new Target records lightweight and inexpensive,
 * the createTarget() function (ETSTarget.sol) requires only a URI string (targetURI).
 *
 * To augment this, we are developing a hybrid onchain/off-chain Enrich Target flow for the purpose of
 * collecting additional metadata about a Target and saving it back on-chain.
 *
 * The flow begins with the requestEnrichTarget() function (see below) which takes a targetId as an
 * argument. If the Target exists, the function emits the targetId via the RequestEnrichTarget event.
 *
 * An OpenZeppelin Defender Sentinel is listening for this event, and when detected, passes the
 * targetId to an ETS off-chain service we call the Enrich Target API, which extracts the Target URI,
 * collects metadata about the URI and saves it in json format to IPFS. The IPFS entpoint is posted
 * back on-chain via fulfillEnrichTarget() thus updating the Target data struct.
 *
 * Future implementation should utilize ChainLink in place of OpenZeppelin for better decentralization.
 */
contract ETSEnrichTarget is IETSEnrichTarget, Initializable, ContextUpgradeable, UUPSUpgradeable {
    /// @dev ETS access controls smart contract.
    IETSAccessControls public etsAccessControls;

    /// @dev ETS access controls smart contract.
    IETSTarget public etsTarget;

    // Public constants

    string public constant NAME = "ETSEnrichTarget";

    // Modifiers

    modifier onlyAdmin() {
        require(etsAccessControls.isAdmin(_msgSender()), "Caller must have administrator access");
        _;
    }

    // ============ UUPS INTERFACE ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IETSAccessControls _etsAccessControls, IETSTarget _etsTarget) public initializer {
        // Initialize access controls & ETS
        etsAccessControls = _etsAccessControls;
        etsTarget = _etsTarget;
    }

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    // ============ PUBLIC INTERFACE ============

    /// @inheritdoc IETSEnrichTarget
    function requestEnrichTarget(uint256 _targetId) public {
        require(etsTarget.targetExistsById(_targetId) == true, "Invalid target");
        // require(!etsTarget.isTargetEnsured(_targetId), "Already ensured");
        emit RequestEnrichTarget(_targetId);
    }

    // ============ OWNER INTERFACE ============

    /// @inheritdoc IETSEnrichTarget
    function fulfillEnrichTarget(
        uint256 _targetId,
        string calldata _ipfsHash,
        uint256 _httpStatus
    ) public {
        require(etsAccessControls.getPlatformAddress() == msg.sender, "only platform may enrich target");
        IETSTarget.Target memory target = etsTarget.getTargetById(_targetId);
        etsTarget.updateTarget(_targetId, target.targetURI, block.timestamp, _httpStatus, _ipfsHash);
    }
}
