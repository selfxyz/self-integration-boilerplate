// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SelfVerificationRoot } from "@selfxyz/contracts/contracts/abstract/SelfVerificationRoot.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";
import { SelfStructs } from "@selfxyz/contracts/contracts/libraries/SelfStructs.sol";
import { SelfUtils } from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts/contracts/interfaces/IIdentityVerificationHubV2.sol";
import { IMailboxV3 } from "./IMailboxV3.sol";
import { TypeCasts } from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

/**
 * @title ProofOfHumanSender
 * @notice Implements SelfVerificationRoot to verify users and send verification data cross-chain via Hyperlane
 * @dev Deployed on source chain (Celo Sepolia or Celo Mainnet)
 */
contract ProofOfHumanSender is SelfVerificationRoot {
    using TypeCasts for address;

    // ============ Immutable Storage ============

    /// @notice Hyperlane Mailbox on source chain
    IMailboxV3 public immutable MAILBOX;

    /// @notice Destination chain domain ID (e.g., Base Sepolia = 84532)
    uint32 public immutable DESTINATION_DOMAIN;

    // ============ Storage ============

    /// @notice Default recipient address on destination chain
    address public defaultRecipient;

    /// @notice Verification result storage
    ISelfVerificationRoot.GenericDiscloseOutputV2 public lastOutput;
    bool public verificationSuccessful;
    bytes public lastUserData;
    address public lastUserAddress;

    /// @notice Verification config storage
    SelfStructs.VerificationConfigV2 public verificationConfig;
    bytes32 public verificationConfigId;

    // ============ Events ============

    /**
     * @notice Emitted when verification is completed
     * @param output The verification output
     * @param userData The user data passed through verification
     */
    event VerificationCompleted(ISelfVerificationRoot.GenericDiscloseOutputV2 output, bytes userData);

    /**
     * @notice Emitted when verification data is sent cross-chain
     * @param messageId Hyperlane message ID
     * @param recipient Recipient address on destination chain
     * @param userAddress The verified user's address
     * @param userIdentifier The user identifier from the disclosure
     */
    event VerificationSentCrossChain(
        bytes32 indexed messageId,
        address indexed recipient,
        address indexed userAddress,
        bytes32 userIdentifier
    );

    // ============ Errors ============

    error ZeroAddressMailbox();
    error ZeroAddressRecipient();
    error InsufficientGasPayment();

    // ============ Constructor ============

    /**
     * @notice Initialize the ProofOfHumanSender contract
     * @param identityVerificationHubV2Address The address of the Identity Verification Hub V2
     * @param scopeSeed The scope seed used to create the scope of the contract
     * @param _verificationConfig The verification configuration for processing proofs
     * @param _mailbox Address of the Hyperlane Mailbox on source chain
     * @param _destinationDomain Domain ID of the destination chain
     * @param _defaultRecipient Default recipient address on destination chain
     */
    constructor(
        address identityVerificationHubV2Address,
        string memory scopeSeed,
        SelfUtils.UnformattedVerificationConfigV2 memory _verificationConfig,
        address _mailbox,
        uint32 _destinationDomain,
        address _defaultRecipient
    )
        SelfVerificationRoot(identityVerificationHubV2Address, scopeSeed)
    {
        if (_mailbox == address(0)) revert ZeroAddressMailbox();
        if (_defaultRecipient == address(0)) revert ZeroAddressRecipient();
        
        // Initialize verification configuration
        verificationConfig = SelfUtils.formatVerificationConfigV2(_verificationConfig);
        verificationConfigId =
            IIdentityVerificationHubV2(identityVerificationHubV2Address).setVerificationConfigV2(verificationConfig);
        
        // Initialize Hyperlane configuration
        MAILBOX = IMailboxV3(_mailbox);
        DESTINATION_DOMAIN = _destinationDomain;
        defaultRecipient = _defaultRecipient;
    }

    /**
     * @notice Receive function to accept refunds from Hyperlane hooks
     * @dev Mailbox hooks refund excess msg.value after paying fees
     */
    receive() external payable {}

    // ============ Internal Functions ============

    /**
     * @notice Implementation of customVerificationHook from SelfVerificationRoot
     * @dev Stores verification data and automatically bridges if ETH was sent
     * @param output The verification output from the hub
     * @param userData The user data passed through verification
     */
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        bytes memory userData
    )
        internal
        override
    {
        // Store verification data
        verificationSuccessful = true;
        lastOutput = output;
        lastUserData = userData;
        lastUserAddress = address(uint160(output.userIdentifier));

        emit VerificationCompleted(output, userData);
        
        // Automatically bridge if contract has ETH balance (sent with verification tx)
        if (address(this).balance > 0) {
            // Encode the verification data
            bytes memory message = abi.encode(
                bytes32(output.userIdentifier),
                lastUserAddress,
                userData,
                block.timestamp
            );
            
            // Convert default recipient address to bytes32 for Hyperlane
            bytes32 recipientBytes32 = defaultRecipient.addressToBytes32();
            
            // Dispatch message via Hyperlane Mailbox
            bytes32 messageId = MAILBOX.dispatch{value: address(this).balance}(
                DESTINATION_DOMAIN,
                recipientBytes32,
                message
            );
            
            emit VerificationSentCrossChain(
                messageId,
                defaultRecipient,
                lastUserAddress,
                bytes32(output.userIdentifier)
            );
        }
    }

    // ============ External Functions ============

    /**
     * @notice Manually send verification data to a custom recipient on destination chain
     * @param recipient Address of the recipient contract on destination chain
     * @return messageId Hyperlane message identifier
     * @dev This is optional - bridging happens automatically in customVerificationHook if ETH is sent with verification
     * @dev Use this function to bridge to a different recipient or re-send verification data
     * @dev Requires payment for gas on destination chain (send ETH with transaction)
     */
    function sendVerificationCrossChain(address recipient)
        external
        payable
        returns (bytes32 messageId)
    {
        if (recipient == address(0)) revert ZeroAddressRecipient();
        if (!verificationSuccessful) revert("No verification to send");
        if (msg.value == 0) revert InsufficientGasPayment();

        // Encode the verification data
        // Note: Only sending basic verification data. Expand to include disclosure fields as needed
        bytes memory message = abi.encode(
            bytes32(lastOutput.userIdentifier),
            lastUserAddress,
            lastUserData,
            block.timestamp
        );

        // Convert recipient address to bytes32 for Hyperlane
        bytes32 recipientBytes32 = recipient.addressToBytes32();

        // Dispatch message via Hyperlane Mailbox
        messageId = MAILBOX.dispatch{value: msg.value}(
            DESTINATION_DOMAIN,
            recipientBytes32,
            message
        );

        emit VerificationSentCrossChain(
            messageId,
            recipient,
            lastUserAddress,
            bytes32(lastOutput.userIdentifier)
        );
    }

    /**
     * @notice Manually re-send verification data to default recipient on destination chain
     * @return messageId Hyperlane message identifier
     * @dev This is optional - bridging to default recipient happens automatically in customVerificationHook
     * @dev Use this function to re-send verification data if needed
     */
    function sendVerificationToDefaultRecipient()
        external
        payable
        returns (bytes32 messageId)
    {
        return this.sendVerificationCrossChain{value: msg.value}(defaultRecipient);
    }

    /**
     * @notice Update the default recipient address
     * @param newRecipient New default recipient address
     * @dev Could add access control here if needed
     */
    function updateDefaultRecipient(address newRecipient) external {
        if (newRecipient == address(0)) revert ZeroAddressRecipient();
        defaultRecipient = newRecipient;
    }

    // ============ View Functions ============

    /**
     * @notice Implementation of getConfigId from SelfVerificationRoot
     * @dev Returns the verification config ID for this contract
     * @return The verification configuration ID
     */
    function getConfigId(
        bytes32, /* destinationChainId */
        bytes32, /* userIdentifier */
        bytes memory /* userDefinedData */
    )
        public
        view
        override
        returns (bytes32)
    {
        return verificationConfigId;
    }

    /**
     * @notice Get the local domain (chain) ID
     * @return Local domain identifier
     */
    function localDomain() external view returns (uint32) {
        return MAILBOX.localDomain();
    }

    /**
     * @notice Check if a message has been delivered
     * @param messageId The message ID to check
     * @return True if delivered, false otherwise
     */
    function isDelivered(bytes32 messageId) external view returns (bool) {
        return MAILBOX.delivered(messageId);
    }
}

