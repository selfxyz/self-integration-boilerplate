// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ProofOfHumanReceiver} from "../src/ProofOfHumanReceiver.sol";
import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";

contract MockMailboxReceiver {
    uint32 public constant localDomain = 84532; // Base Sepolia
    
    function delivered(bytes32) external pure returns (bool) {
        return false;
    }
}

contract ProofOfHumanReceiverTest is Test {
    using TypeCasts for address;
    
    ProofOfHumanReceiver public receiver;
    MockMailboxReceiver public mailbox;
    
    uint32 constant CELO_SEPOLIA_DOMAIN = 11142220;
    address public owner = address(this);
    address public senderContract = address(0xABCD);
    address public user = address(0xBEEF);
    
    function setUp() public {
        mailbox = new MockMailboxReceiver();
        receiver = new ProofOfHumanReceiver(address(mailbox), CELO_SEPOLIA_DOMAIN);
    }

    function test_Constructor() public view {
        assertEq(address(receiver.MAILBOX()), address(mailbox));
        assertEq(receiver.SOURCE_DOMAIN(), CELO_SEPOLIA_DOMAIN);
        assertEq(receiver.owner(), owner);
        assertFalse(receiver.enforceTrustedSenders());
    }

    function test_LocalDomain() public view {
        assertEq(receiver.localDomain(), 84532);
    }

    function test_HandleMessage() public {
        // Prepare message data
        bytes32 userIdentifier = bytes32(uint256(0x1111));
        bytes memory userData = "test data";
        uint256 verifiedAt = block.timestamp - 100;
        
        bytes memory message = abi.encode(
            userIdentifier,
            user,
            userData,
            verifiedAt
        );
        
        // Call handle as mailbox
        vm.prank(address(mailbox));
        receiver.handle(CELO_SEPOLIA_DOMAIN, senderContract.addressToBytes32(), message);
        
        // Verify storage
        assertTrue(receiver.isVerified(user));
        assertEq(receiver.verificationCount(), 1);
        assertEq(receiver.getUserAddress(userIdentifier), user);
        
        // Check verification data
        ProofOfHumanReceiver.VerificationData memory data = receiver.getVerification(user);
        assertEq(data.userIdentifier, userIdentifier);
        assertEq(data.userAddress, user);
        assertEq(data.userData, userData);
        assertEq(data.verifiedAt, verifiedAt);
        assertTrue(data.exists);
        assertTrue(data.isVerified);
    }

    function test_HandleMessageRevertsFromNonMailbox() public {
        bytes memory message = abi.encode(bytes32(0), user, "", block.timestamp);
        
        vm.expectRevert(ProofOfHumanReceiver.NotMailbox.selector);
        receiver.handle(CELO_SEPOLIA_DOMAIN, senderContract.addressToBytes32(), message);
    }

    function test_HandleMessageRevertsFromWrongOrigin() public {
        bytes memory message = abi.encode(bytes32(0), user, "", block.timestamp);
        
        vm.prank(address(mailbox));
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofOfHumanReceiver.InvalidOrigin.selector,
                12345,
                CELO_SEPOLIA_DOMAIN
            )
        );
        receiver.handle(12345, senderContract.addressToBytes32(), message);
    }

    function test_TrustedSenderEnforcement() public {
        // Enable enforcement
        receiver.setTrustedSenderEnforcement(true);
        assertTrue(receiver.enforceTrustedSenders());
        
        // Try to receive message from untrusted sender (should fail)
        bytes memory message = abi.encode(bytes32(0), user, "", block.timestamp);
        
        vm.prank(address(mailbox));
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofOfHumanReceiver.UntrustedSender.selector,
                senderContract.addressToBytes32()
            )
        );
        receiver.handle(CELO_SEPOLIA_DOMAIN, senderContract.addressToBytes32(), message);
        
        // Add trusted sender
        receiver.addTrustedSender(senderContract);
        assertTrue(receiver.isTrustedSender(senderContract));
        
        // Now it should work
        vm.prank(address(mailbox));
        receiver.handle(CELO_SEPOLIA_DOMAIN, senderContract.addressToBytes32(), message);
        
        assertTrue(receiver.isVerified(user));
    }

    function test_AddTrustedSender() public {
        receiver.addTrustedSender(senderContract);
        assertTrue(receiver.isTrustedSender(senderContract));
    }

    function test_RemoveTrustedSender() public {
        receiver.addTrustedSender(senderContract);
        assertTrue(receiver.isTrustedSender(senderContract));
        
        receiver.removeTrustedSender(senderContract);
        assertFalse(receiver.isTrustedSender(senderContract));
    }

    function test_OnlyOwnerCanSetTrustedSenderEnforcement() public {
        vm.prank(user);
        vm.expectRevert();
        receiver.setTrustedSenderEnforcement(true);
    }

    function test_OnlyOwnerCanAddTrustedSender() public {
        vm.prank(user);
        vm.expectRevert();
        receiver.addTrustedSender(senderContract);
    }

    function test_MultipleVerifications() public {
        address user2 = address(0xCAFE);
        bytes32 userIdentifier1 = bytes32(uint256(0x1111));
        bytes32 userIdentifier2 = bytes32(uint256(0x2222));
        
        // First verification
        bytes memory message1 = abi.encode(userIdentifier1, user, "data1", block.timestamp);
        vm.prank(address(mailbox));
        receiver.handle(CELO_SEPOLIA_DOMAIN, senderContract.addressToBytes32(), message1);
        
        // Second verification
        bytes memory message2 = abi.encode(userIdentifier2, user2, "data2", block.timestamp);
        vm.prank(address(mailbox));
        receiver.handle(CELO_SEPOLIA_DOMAIN, senderContract.addressToBytes32(), message2);
        
        // Both should be verified
        assertTrue(receiver.isVerified(user));
        assertTrue(receiver.isVerified(user2));
        assertEq(receiver.verificationCount(), 2);
        
        // Check mappings
        assertEq(receiver.getUserAddress(userIdentifier1), user);
        assertEq(receiver.getUserAddress(userIdentifier2), user2);
    }
}
