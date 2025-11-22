// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProofOfHumanReceiver} from "../src/ProofOfHumanReceiver.sol";

/**
 * @title DeployProofOfHumanReceiver
 * @notice Deployment script for ProofOfHumanReceiver contract on destination chain
 * @dev Example deployment to Base Sepolia receiving from Celo Sepolia
 * 
 * Run with:
 * forge script script/DeployProofOfHumanReceiver.s.sol:DeployProofOfHumanReceiver \
 *   --rpc-url base-sepolia \
 *   --broadcast \
 *   --verify
 */
contract DeployProofOfHumanReceiver is Script {
    // ============ Base Sepolia Configuration ============
    
    /// @notice Hyperlane Mailbox on Base Sepolia
    address constant MAILBOX_BASE_SEPOLIA = 0x6966b0E55883d49BFB24539356a2f8A673E02039;
    
    /// @notice Celo Sepolia domain ID (same as chain ID for Hyperlane)
    uint32 constant CELO_SEPOLIA_DOMAIN = 11142220;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== Deploying ProofOfHumanReceiver on Base Sepolia ===");
        console2.log("Deployer:", deployer);
        console2.log("Mailbox:", MAILBOX_BASE_SEPOLIA);
        console2.log("Source Domain (Celo Sepolia):", CELO_SEPOLIA_DOMAIN);

        vm.startBroadcast(deployerPrivateKey);

        ProofOfHumanReceiver receiver = new ProofOfHumanReceiver(
            MAILBOX_BASE_SEPOLIA,
            CELO_SEPOLIA_DOMAIN
        );

        vm.stopBroadcast();

        console2.log("\n=== Deployment Complete ===");
        console2.log("ProofOfHumanReceiver deployed at:", address(receiver));
        console2.log("Local domain:", receiver.localDomain());
        console2.log("Expected origin (Celo Sepolia):", receiver.SOURCE_DOMAIN());
        console2.log("Trusted sender enforcement:", receiver.enforceTrustedSenders());
        console2.log("Owner:", receiver.owner());

        console2.log("\n=== Next Steps ===");
        console2.log("1. Add this to .env:");
        console2.log("   RECEIVER_ADDRESS=%s", address(receiver));
        console2.log("2. Deploy ProofOfHumanSender on Celo Sepolia with this receiver address");
        console2.log("3. Optionally enable trusted sender enforcement:");
        console2.log("   cast send %s 'setTrustedSenderEnforcement(bool)' true --rpc-url base-sepolia", address(receiver));
    }
}
