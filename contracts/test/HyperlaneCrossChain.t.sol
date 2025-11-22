// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ProofOfHumanSender} from "../src/ProofOfHumanSender.sol";
import {ProofOfHumanReceiver} from "../src/ProofOfHumanReceiver.sol";
import {IMessageRecipient} from "@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {SelfUtils} from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";
import {SelfStructs} from "@selfxyz/contracts/contracts/libraries/SelfStructs.sol";

contract MockIdentityHubCrossChain {
    function setVerificationConfigV2(SelfStructs.VerificationConfigV2 memory) external pure returns (bytes32) {
        return keccak256("mock-config-id");
    }
}

/**
 * @title HyperlaneCrossChainTest
 * @notice Integration test simulating full cross-chain verification flow
 */
contract HyperlaneCrossChainTest is Test {
    using TypeCasts for address;
    
    // Mock Hyperlane infrastructure
    MockHyperlaneMailbox public celoMailbox;
    MockHyperlaneMailbox public baseMailbox;
    
    ProofOfHumanSender public sender;
    ProofOfHumanReceiver public receiver;
    
    MockIdentityHubCrossChain public mockIdentityHub;
    address public user = address(0xBEEF);
    
    uint32 constant CELO_SEPOLIA_DOMAIN = 11142220;
    uint32 constant BASE_SEPOLIA_DOMAIN = 84532;

    function setUp() public {
        // Deploy mock mailboxes
        celoMailbox = new MockHyperlaneMailbox(CELO_SEPOLIA_DOMAIN);
        baseMailbox = new MockHyperlaneMailbox(BASE_SEPOLIA_DOMAIN);
        
        // Connect mailboxes for cross-chain messaging
        celoMailbox.setRemoteMailbox(BASE_SEPOLIA_DOMAIN, address(baseMailbox));
        baseMailbox.setRemoteMailbox(CELO_SEPOLIA_DOMAIN, address(celoMailbox));
        
        mockIdentityHub = new MockIdentityHubCrossChain();
        
        // Create verification config
        string[] memory forbiddenCountries = new string[](0);
        SelfUtils.UnformattedVerificationConfigV2 memory verificationConfig = 
            SelfUtils.UnformattedVerificationConfigV2({
                olderThan: 18,
                forbiddenCountries: forbiddenCountries,
                ofacEnabled: false
            });
        
        // Deploy receiver on Base (no verification config needed - only receives messages)
        receiver = new ProofOfHumanReceiver(
            address(baseMailbox),
            CELO_SEPOLIA_DOMAIN
        );
        
        // Deploy sender on Celo (performs Self Protocol verification)
        sender = new ProofOfHumanSender(
            address(mockIdentityHub),
            "test-scope-sender",
            verificationConfig,
            address(celoMailbox),
            BASE_SEPOLIA_DOMAIN,
            address(receiver)
        );
        
        // Add sender as trusted on receiver
        receiver.addTrustedSender(address(sender));
    }

    function test_FullCrossChainFlow() public {
        // Step 1: Simulate verification on Celo (normally done by identity hub)
        // We can't easily trigger this without the full Self Protocol, so we'll
        // test the cross-chain messaging assuming verification happened
        
        console2.log("Testing cross-chain verification flow");
        console2.log("Sender (Celo):", address(sender));
        console2.log("Receiver (Base):", address(receiver));
        
        // For now, verify that the contracts are properly configured
        assertEq(sender.DESTINATION_DOMAIN(), BASE_SEPOLIA_DOMAIN);
        assertEq(receiver.SOURCE_DOMAIN(), CELO_SEPOLIA_DOMAIN);
        assertEq(sender.defaultRecipient(), address(receiver));
        assertTrue(receiver.isTrustedSender(address(sender)));
    }
    
    function test_MessageFormat() public {
        // Test that message encoding/decoding works correctly
        bytes32 userIdentifier = bytes32(uint256(0x1111));
        address userAddress = address(0xBEEF);
        bytes memory userData = "test data";
        uint256 verifiedAt = block.timestamp;
        
        // Encode as sender would
        bytes memory message = abi.encode(
            userIdentifier,
            userAddress,
            userData,
            verifiedAt
        );
        
        // Decode as receiver would
        (
            bytes32 decodedId,
            address decodedAddress,
            bytes memory decodedData,
            uint256 decodedTime
        ) = abi.decode(message, (bytes32, address, bytes, uint256));
        
        assertEq(decodedId, userIdentifier);
        assertEq(decodedAddress, userAddress);
        assertEq(decodedData, userData);
        assertEq(decodedTime, verifiedAt);
    }
    
    function test_CrossChainDelivery() public {
        // Simulate a cross-chain message delivery
        bytes32 userIdentifier = bytes32(uint256(0x1111));
        bytes memory userData = "verified user";
        uint256 verifiedAt = block.timestamp;
        
        bytes memory message = abi.encode(
            userIdentifier,
            user,
            userData,
            verifiedAt
        );
        
        // Fund the sender for gas
        vm.deal(address(this), 1 ether);
        
        // Dispatch message from Celo mailbox
        bytes32 messageId = celoMailbox.dispatch{value: 0.001 ether}(
            BASE_SEPOLIA_DOMAIN,
            address(receiver).addressToBytes32(),
            message
        );
        
        // Simulate message delivery to Base
        celoMailbox.processMessage(messageId);
        
        // Verify the message was received
        assertTrue(receiver.isVerified(user));
        assertEq(receiver.getUserAddress(userIdentifier), user);
        
        ProofOfHumanReceiver.VerificationData memory data = receiver.getVerification(user);
        assertEq(data.userIdentifier, userIdentifier);
        assertEq(data.userAddress, user);
        assertTrue(data.isVerified);
    }
}

/**
 * @notice Mock Hyperlane mailbox for testing
 */
contract MockHyperlaneMailbox {
    using TypeCasts for address;
    using TypeCasts for bytes32;
    
    uint32 public immutable localDomain;
    uint256 public messageCount;
    
    mapping(bytes32 => MessageData) public messages;
    mapping(uint32 => address) public remoteMailboxes;
    
    struct MessageData {
        uint32 destination;
        bytes32 recipient;
        bytes body;
        bool processed;
    }
    
    constructor(uint32 _domain) {
        localDomain = _domain;
    }
    
    function setRemoteMailbox(uint32 domain, address mailbox) external {
        remoteMailboxes[domain] = mailbox;
    }
    
    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable returns (bytes32 messageId) {
        messageId = keccak256(abi.encode(localDomain, destinationDomain, messageCount++, messageBody));
        
        messages[messageId] = MessageData({
            destination: destinationDomain,
            recipient: recipientAddress,
            body: messageBody,
            processed: false
        });
        
        return messageId;
    }
    
    function processMessage(bytes32 messageId) external {
        MessageData storage message = messages[messageId];
        require(!message.processed, "Already processed");
        
        address remoteMailbox = remoteMailboxes[message.destination];
        require(remoteMailbox != address(0), "No remote mailbox");
        
        // Simulate message delivery - call the remote mailbox to deliver
        MockHyperlaneMailbox(remoteMailbox).deliverMessage(
            localDomain,
            address(this).addressToBytes32(),
            message.recipient.bytes32ToAddress(),
            message.body
        );
        
        message.processed = true;
    }
    
    function deliverMessage(
        uint32 origin,
        bytes32 sender,
        address recipient,
        bytes memory messageBody
    ) external {
        // This function is called by the remote mailbox to deliver a message
        // It pranks to make the call appear to come from this mailbox
        IMessageRecipient(recipient).handle(origin, sender, messageBody);
    }
    
    function delivered(bytes32 messageId) external view returns (bool) {
        return messages[messageId].processed;
    }
}

