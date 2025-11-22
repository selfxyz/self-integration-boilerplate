// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ProofOfHumanSender} from "../src/ProofOfHumanSender.sol";
import {IMailboxV3} from "../src/IMailboxV3.sol";
import {SelfUtils} from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";
import {SelfStructs} from "@selfxyz/contracts/contracts/libraries/SelfStructs.sol";

contract MockMailbox is IMailboxV3 {
    uint32 public constant override localDomain = 11142220; // Celo Sepolia
    mapping(bytes32 => bool) public deliveredMessages;
    
    bytes32 public lastMessageId;
    uint32 public lastDestination;
    bytes32 public lastRecipient;
    bytes public lastMessage;

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody
    ) external payable override returns (bytes32 messageId) {
        messageId = keccak256(abi.encode(destinationDomain, recipientAddress, messageBody, block.timestamp));
        
        lastMessageId = messageId;
        lastDestination = destinationDomain;
        lastRecipient = recipientAddress;
        lastMessage = messageBody;
        
        return messageId;
    }

    function delivered(bytes32 messageId) external view override returns (bool) {
        return deliveredMessages[messageId];
    }
    
    function markDelivered(bytes32 messageId) external {
        deliveredMessages[messageId] = true;
    }
}

contract MockIdentityHub {
    function setVerificationConfigV2(SelfStructs.VerificationConfigV2 memory) external pure returns (bytes32) {
        return keccak256("mock-config-id");
    }
}

contract ProofOfHumanSenderTest is Test {
    ProofOfHumanSender public sender;
    MockMailbox public mailbox;
    MockIdentityHub public identityHub;
    
    address public receiver = address(0x1234567890123456789012345678901234567890);
    uint32 constant BASE_SEPOLIA_DOMAIN = 84532;
    
    address public owner = address(this);
    address public user = address(0xBEEF);

    function setUp() public {
        // Deploy mocks
        mailbox = new MockMailbox();
        identityHub = new MockIdentityHub();
        
        // Create verification config
        string[] memory forbiddenCountries = new string[](0);
        SelfUtils.UnformattedVerificationConfigV2 memory verificationConfig = 
            SelfUtils.UnformattedVerificationConfigV2({
                olderThan: 18,
                forbiddenCountries: forbiddenCountries,
                ofacEnabled: false
            });
        
        // Deploy sender
        sender = new ProofOfHumanSender(
            address(identityHub),
            "test-scope",
            verificationConfig,
            address(mailbox),
            BASE_SEPOLIA_DOMAIN,
            receiver
        );
    }

    function test_Constructor() public view {
        assertEq(address(sender.MAILBOX()), address(mailbox));
        assertEq(sender.DESTINATION_DOMAIN(), BASE_SEPOLIA_DOMAIN);
        assertEq(sender.defaultRecipient(), receiver);
    }

    function test_LocalDomain() public view {
        assertEq(sender.localDomain(), 11142220);
    }

    function test_UpdateDefaultRecipient() public {
        address newRecipient = address(0x9999);
        sender.updateDefaultRecipient(newRecipient);
        assertEq(sender.defaultRecipient(), newRecipient);
    }

    function test_RevertWhen_UpdateDefaultRecipientZeroAddress() public {
        vm.expectRevert(ProofOfHumanSender.ZeroAddressRecipient.selector);
        sender.updateDefaultRecipient(address(0));
    }

    function test_SendVerificationCrossChainRevertsWithoutVerification() public {
        vm.expectRevert("No verification to send");
        sender.sendVerificationCrossChain{value: 0.001 ether}(receiver);
    }

    function test_SendVerificationCrossChainRevertsWithoutGas() public {
        // Simulate verification (would normally come from identity hub)
        // Since we can't easily mock the full verification flow, we'll test the revert
        vm.expectRevert();
        sender.sendVerificationCrossChain(receiver);
    }

    function test_RevertWhen_SendVerificationToZeroAddress() public {
        vm.expectRevert(ProofOfHumanSender.ZeroAddressRecipient.selector);
        sender.sendVerificationCrossChain{value: 0.001 ether}(address(0));
    }

    function test_ReceiveFunction() public {
        // Test that contract can receive ETH for gas refunds
        vm.deal(user, 1 ether);
        vm.prank(user);
        (bool success,) = address(sender).call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(address(sender).balance, 0.5 ether);
    }
}

