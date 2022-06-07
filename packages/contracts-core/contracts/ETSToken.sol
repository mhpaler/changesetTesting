// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IETSToken.sol";
import "./interfaces/IETSAccessControls.sol";
//import "./interfaces/IETSPublisherControls.sol";
import "./utils/StringHelpers.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "hardhat/console.sol";


/// @title ETS ERC-721 NFT contract
/// @author Ethereum Tag Service <security@ets.xyz>
/// @notice Contract that governs the creation of CTAG non-fungible tokens.
/// @dev UUPS upgradable.
contract ETSToken is ERC721PausableUpgradeable, ERC721BurnableUpgradeable, IETSToken, UUPSUpgradeable, StringHelpers {

    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;


    IETSAccessControls public etsAccessControls;
    // IETSPublisherControls public etsPublisherControls;

    /// Public constants
    string public constant NAME = "CTAG Token";
    string public constant VERSION = "0.1.0";

    uint256 public tagMinStringLength;
    uint256 public tagMaxStringLength;
    uint256 public ownershipTermLength;

    /// @dev ETS Platform account.
    address payable public platform;

    /// @dev Map of CTAG id to CTAG record.
    mapping(uint256 => Tag) public tokenIdToTag;

    /// @dev Mapping of tokenId to last renewal.
    mapping(uint256 => uint256) public tokenIdToLastRenewed;


    /// Modifiers

    modifier onlyAdmin() {
        require(etsAccessControls.isAdmin(_msgSender()), "Caller must have administrator access");
        _;
    }

    // ============ UUPS INTERFACE ============

    function initialize(
        IETSAccessControls _etsAccessControls,
        // IETSPublisherControls _etsPublisherControls,
        address payable _platform
    ) public initializer {
        __ERC721_init("Ethereum Tag Service", "CTAG");
        __ERC721Pausable_init();
        __ERC721Burnable_init();

        etsAccessControls = _etsAccessControls;
        //etsPublisherControls = _etsPublisherControls;
        platform = _platform;

        tagMinStringLength = 2;
        tagMaxStringLength = 32;
        ownershipTermLength = 730 days;

    }

    function _authorizeUpgrade(address) internal override onlyAdmin {}

    // @vince Not sure if we need this at all?
    //function supportsInterface(bytes4 interfaceId) public view virtual override(IERC721Upgradeable) returns (bool) {
    //    return super.supportsInterface(interfaceId);
    //}

    // ============ OWNER INTERFACE ============

    /// @dev Pause CTAG token contract.
    function pause() external onlyAdmin {
        _pause();
    }

    /// @dev Unpause CTAG token contract.
    function unPause() external onlyAdmin {
        _unpause();
    }

    function burn(uint256 tokenId) public override onlyAdmin {
        _burn(tokenId);
    }

    function setTagMaxStringLength(uint256 _tagMaxStringLength) public onlyAdmin {
        tagMaxStringLength = _tagMaxStringLength;
        emit TagMaxStringLengthSet(_tagMaxStringLength);
    }

    function setOwnershipTermLength(uint256 _ownershipTermLength) public onlyAdmin {
        ownershipTermLength = _ownershipTermLength;
        emit OwnershipTermLengthSet(_ownershipTermLength);
    }

    function setPlatform(address payable _platform) public onlyAdmin {
        platform = _platform;
        emit PlatformSet(_platform);
    }

    function setAccessControls(IETSAccessControls _etsAccessControls) public onlyAdmin {
        require(address(_etsAccessControls) != address(0), "ETS: Access controls cannot be zero");
        etsAccessControls = _etsAccessControls;
        emit AccessControlsSet(_etsAccessControls);
    }

    // ============ PUBLIC INTERFACE ============

    function createTag(
        string calldata _tag,
        address payable _publisher
    ) external payable returns (uint256 _tokenId) {
        require(etsAccessControls.isPublisher(_publisher), "ETS: Not a publisher");

        // Perform basic tag string validation.
        uint256 tagId = _assertTagIsValid(_tag);

        // mint the token, transferring it to the platform.
        _safeMint(platform, tagId);//todo - need to add a re-entrancy guard if we are going to use safe mint

        // Store CTAG data in state.
        tokenIdToTag[tagId] = Tag({
            displayVersion: _tag,
            // TODO - need to sense check this. I don't believe machine name needs to be stored because it can always be computed from displayVersion field
            // machineName: machineName,
            originalPublisher: _publisher,
            creator: _msgSender()
        });

        // todo - I believe this event can be removed. The internal mint method already emits an event and you can get everything from the token ID
        // emit TagMinted(tagId, _tag, _publisher, _msgSender());
        return tagId;
    }

    function renewTag(uint256 _tokenId) public {
        require(_exists(_tokenId), "ETS: CTAG not found");
        // Handle new and recycled CTAGS.
        if (ownerOf(_tokenId) == platform) {
            _setLastRenewed(_tokenId, 0);
        } else {
            // require(ownerOf(_tokenId) == msg.sender, "ETS: Renew tag invalid sender");
            _setLastRenewed(_tokenId, block.timestamp);
        }

        emit TagRenewed(_tokenId, msg.sender);
    }

    /**
     * @dev allows anyone or thing to recycle a CTAG back to platform if
       ownership term is expired.
     */
    function recycleTag(uint256 _tokenId) public {
        require(_exists(_tokenId), "ETS: CTAG not found");
        require(ownerOf(_tokenId) != platform, "ETS: CTAG owned by platform");
   
        uint256 lastRenewed = getLastRenewed(_tokenId);
        require(
            lastRenewed.add(getOwnershipTermLength()) < block.timestamp,
            "ETS: CTAG not eligible for recycling"
        );

        _transfer(ownerOf(_tokenId), platform, _tokenId);
        emit TagRecycled(_tokenId, _msgSender());
    }

    // ============ PUBLIC VIEW FUNCTIONS ============

    function computeTagId(string memory _tag) public pure returns (uint256) {
        string memory _machineName = __lower(_tag);
        return uint256(keccak256(bytes(_machineName)));
    }

    function tokenIdExists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function tagExists(string calldata _tag) public view returns (bool) {
        return _exists(computeTagId(_tag));
    }

    function getTag(uint256 _tokenId) public view returns (Tag memory) {
        return tokenIdToTag[_tokenId];
    }

    function getOwnershipTermLength() public view returns (uint256) {
        return ownershipTermLength;
    }

    function getLastRenewed(uint256 _tokenId) public view returns (uint256) {
        return tokenIdToLastRenewed[_tokenId];
    }

    /// @dev Returns the commission addresses related to a token.
    /// @param _tokenId ID of a CTAG.
    /// @return _platform Platform commission address.
    /// @return _owner Address of the owner of the CTAG.
    function getPaymentAddresses(uint256 _tokenId)
        public
        view
        returns (
            address payable _platform,
            address payable _owner
        )
    {
        return (
            platform,
            payable(ownerOf(_tokenId))
        );
    }

    /// @notice Returns creator of a CTAG token.
    /// @param _tokenId ID of a CTAG.
    /// @return _creator creator of the CTAG.
    function getCreatorAddress(uint256 _tokenId) public view returns (address _creator) {
        return tokenIdToTag[_tokenId].creator;
    }

    function getPlatformAddress() public view returns (address) {
        return platform;
    }

    function version() external pure returns (string memory) {
        return VERSION;
    }

    // ============ INTERNAL FUNCTIONS ============

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC721PausableUpgradeable, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @dev See {ERC721-_afterTokenTransfer}. Contract must not be paused.
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Upgradeable) {
        super._afterTokenTransfer(from, to, tokenId);

        require(!paused(), "ERC721Pausable: token transfer while paused");

        // Reset token ownership term.
        if (to != address(0)) {
            renewTag(tokenId);
        }
        // TODO: After auction is set up.
        // if () {
        //     etsPublisherControls.promoteToPublisher(to);
        // }
    }

    /// @notice Private method used for validating a CTAG string before minting.
    /// @dev A series of assertions are performed reverting the transaction for any validation violations.
    /// @param _tag Proposed tag string.
    function _assertTagIsValid(string memory _tag) private view returns (uint256 _tagId) {
        // generate token ID from machine name
        uint256 tagId = computeTagId(_tag);

        require(!_exists(tagId), "ERC721: token already minted");

        bytes memory tagStringBytes = bytes(_tag);
        require(
            tagStringBytes.length >= tagMinStringLength && tagStringBytes.length <= tagMaxStringLength,
            "Invalid format: tag does not meet min/max length requirements"
        );

        require(tagStringBytes[0] == 0x23, "Tag must start with #");

        // start from first char after #
        for (uint256 i = 1; i < tagStringBytes.length; i++) {
            bytes1 char = tagStringBytes[i];
            require(
                char != 0x20,
                "Space found: tag may not contain spaces"
            );
            require(
                char != 0x23,
                "Tag may not contain prefix"
            );
        }

        return tagId;
    }

   function _setLastRenewed(uint256 _tokenId, uint256 _timestamp) internal {
       tokenIdToLastRenewed[_tokenId] = _timestamp;
   }
}
