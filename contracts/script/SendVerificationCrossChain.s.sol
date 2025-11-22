// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProofOfHumanSender} from "../src/ProofOfHumanSender.sol";

/**
 * @title SendVerificationCrossChain
 * @notice Script to manually send verification data cross-chain after user has been verified
 * @dev NOTE: With automatic bridging enabled, this script is optional.
 *      Verification data is automatically bridged when ETH is sent with the verification transaction.
 *      Use this script only if you need to manually re-send verification data or send to a custom recipient.
 * 
 * Run with:
 * forge script script/SendVerificationCrossChain.s.sol:SendVerificationCrossChain \
 *   --rpc-url celo-sepolia \
 *   --broadcast
 */
contract SendVerificationCrossChain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address senderAddress = vm.envAddress("SENDER_ADDRESS");
        address receiverAddress = vm.envAddress("RECEIVER_ADDRESS");

        console2.log("=== Manually Sending Verification Cross-Chain ===");
        console2.log("Sender contract:", senderAddress);
        console2.log("Receiver contract:", receiverAddress);
        console2.log("\nNOTE: If automatic bridging is enabled, this is optional.");

        ProofOfHumanSender sender = ProofOfHumanSender(payable(senderAddress));

        // Check if verification exists
        require(sender.verificationSuccessful(), "No verification to send");
        
        console2.log("Last verified user:", sender.lastUserAddress());

        vm.startBroadcast(deployerPrivateKey);

        // Send with 0.001 ether for gas (adjust as needed)
        bytes32 messageId = sender.sendVerificationCrossChain{value: 0.001 ether}(
            receiverAddress
        );

        vm.stopBroadcast();

        console2.log("\n=== Message Sent ===");
        console2.log("Message ID:", uint256(messageId));
        console2.log("\n=== Track Message ===");
        console2.log("Hyperlane Explorer:");
        console2.log("https://explorer.hyperlane.xyz/message/%s", uint256(messageId));
        console2.log("\nCheck delivery with:");
        console2.log("cast call %s 'isDelivered(bytes32)(bool)' %s --rpc-url celo-sepolia", 
            senderAddress, uint256(messageId));
    }
}

