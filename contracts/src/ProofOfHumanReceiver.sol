// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMessageRecipient } from "@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol";
import { IMailbox } from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import { TypeCasts } from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ProofOfHumanReceiver
 * @notice Receives cross-chain verification data from ProofOfHumanSender via Hyperlane
 * @dev Deployed on destination chain (Base Sepolia or Base Mainnet)
 */
contract ProofOfHumanReceiver is IMessageRecipient, Ownable {
    using TypeCasts for bytes32;
    using TypeCasts for address;

    // ============ Immutable Storage ============

    /// @notice Source chain domain ID (Celo Sepolia = 11142220, Celo Mainnet = 42220)
    uint32 public immutable SOURCE_DOMAIN;

    /// @notice Hyperlane Mailbox on destination chain
    IMailbox public immutable MAILBOX;

    // ============ Storage ============

    /// @notice Mapping of user address to their verification data
    mapping(address => VerificationData) public verifications;

    /// @notice Mapping of user identifier to user address
    mapping(bytes32 => address) public userIdentifierToAddress;

    /// @notice Counter of total verifications received
    uint256 public verificationCount;

    /// @notice Trusted sender addresses from source chain
    mapping(bytes32 => bool) public trustedSenders;

    /// @notice Whether to enforce trusted senders check
    bool public enforceTrustedSenders;

    // ============ Structs ============

    struct VerificationData {
        bytes32 userIdentifier;
        address userAddress;
        bytes userData;
        uint256 verifiedAt;
        uint256 receivedAt;
        bool exists;
        bool isVerified;
    }

    // ============ Events ============

    /**
     * @notice Emitted when verification data is received from source chain
     * @param userAddress The verified user's address
     * @param userIdentifier The user identifier
     * @param receivedAt When the verification was received
     */
    event VerificationReceived(
        address indexed userAddress,
        bytes32 indexed userIdentifier,
        uint256 receivedAt
    );

    /**
     * @notice Emitted when a trusted sender is added
     * @param sender Sender address (as bytes32)
     */
    event TrustedSenderAdded(bytes32 indexed sender);

    /**
     * @notice Emitted when a trusted sender is removed
     * @param sender Sender address (as bytes32)
     */
    event TrustedSenderRemoved(bytes32 indexed sender);

    /**
     * @notice Emitted when trusted sender enforcement is toggled
     * @param enabled Whether enforcement is enabled
     */
    event TrustedSenderEnforcementToggled(bool enabled);

    // ============ Errors ============

    error NotMailbox();
    error InvalidOrigin(uint32 received, uint32 expected);
    error UntrustedSender(bytes32 sender);
    error ZeroAddressMailbox();

    // ============ Constructor ============

    /**
     * @notice Initialize the ProofOfHumanReceiver contract
     * @param _mailbox Address of the Hyperlane Mailbox on destination chain
     * @param _sourceDomain Domain ID of the source chain
     */
    constructor(address _mailbox, uint32 _sourceDomain) Ownable(msg.sender) {
        if (_mailbox == address(0)) revert ZeroAddressMailbox();
        MAILBOX = IMailbox(_mailbox);
        SOURCE_DOMAIN = _sourceDomain;
        enforceTrustedSenders = false; // Start permissionless
    }

    // ============ External Functions ============

    /**
     * @notice Handle incoming verification messages from Hyperlane
     * @param _origin Domain ID of the origin chain
     * @param _sender Sender address on the origin chain (as bytes32)
     * @param _message Message body containing verification data
     * @dev This function can only be called by the Hyperlane Mailbox
     */
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external override {
        // Verify caller is the Mailbox
        if (msg.sender != address(MAILBOX)) revert NotMailbox();

        // Verify origin is the expected source chain
        if (_origin != SOURCE_DOMAIN) {
            revert InvalidOrigin(_origin, SOURCE_DOMAIN);
        }

        // Optional: Check if sender is trusted (if enforcement enabled)
        if (enforceTrustedSenders && !trustedSenders[_sender]) {
            revert UntrustedSender(_sender);
        }

        // Decode the verification data
        (
            bytes32 userIdentifier,
            address userAddress,
            bytes memory userData,
            uint256 verifiedAt
        ) = abi.decode(_message, (bytes32, address, bytes, uint256));

        // Store the verification data
        verifications[userAddress] = VerificationData({
            userIdentifier: userIdentifier,
            userAddress: userAddress,
            userData: userData,
            verifiedAt: verifiedAt,
            receivedAt: block.timestamp,
            exists: true,
            isVerified: true
        });

        // Map user identifier to address for easy lookup
        userIdentifierToAddress[userIdentifier] = userAddress;

        verificationCount++;

        emit VerificationReceived(
            userAddress,
            userIdentifier,
            block.timestamp
        );
    }

    // ============ Owner Functions ============

    /**
     * @notice Toggle trusted sender enforcement
     * @param enabled Whether to enforce trusted senders
     */
    function setTrustedSenderEnforcement(bool enabled) external onlyOwner {
        enforceTrustedSenders = enabled;
        emit TrustedSenderEnforcementToggled(enabled);
    }

    /**
     * @notice Add a trusted sender address
     * @param sender Sender address on source chain
     */
    function addTrustedSender(address sender) external onlyOwner {
        bytes32 senderBytes32 = sender.addressToBytes32();
        trustedSenders[senderBytes32] = true;
        emit TrustedSenderAdded(senderBytes32);
    }

    /**
     * @notice Remove a trusted sender address
     * @param sender Sender address on source chain
     */
    function removeTrustedSender(address sender) external onlyOwner {
        bytes32 senderBytes32 = sender.addressToBytes32();
        trustedSenders[senderBytes32] = false;
        emit TrustedSenderRemoved(senderBytes32);
    }

    // ============ View Functions ============

    /**
     * @notice Check if a user is verified
     * @param userAddress The user's address
     * @return True if verified, false otherwise
     */
    function isVerified(address userAddress) external view returns (bool) {
        return verifications[userAddress].isVerified;
    }

    /**
     * @notice Get verification data for a user
     * @param userAddress The user's address
     * @return VerificationData struct
     */
    function getVerification(address userAddress)
        external
        view
        returns (VerificationData memory)
    {
        return verifications[userAddress];
    }

    /**
     * @notice Get user address by user identifier
     * @param userIdentifier The user identifier
     * @return The user's address
     */
    function getUserAddress(bytes32 userIdentifier)
        external
        view
        returns (address)
    {
        return userIdentifierToAddress[userIdentifier];
    }

    /**
     * @notice Check if a sender is trusted
     * @param sender Sender address
     * @return True if trusted, false otherwise
     */
    function isTrustedSender(address sender) external view returns (bool) {
        return trustedSenders[sender.addressToBytes32()];
    }

    /**
     * @notice Get the local domain (chain) ID
     * @return Local domain identifier
     */
    function localDomain() external view returns (uint32) {
        return MAILBOX.localDomain();
    }
}

