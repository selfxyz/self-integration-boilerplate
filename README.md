# Self Protocol Boilerplate Example with Hyperlane Bridging

Learn to build privacy-preserving identity verification with [Self Protocol](https://self.xyz/) and bridge it cross-chain using [Hyperlane](https://hyperlane.xyz/) - verify on Celo, use on Base!

> 📺 **New to Self?** Watch the [ETHGlobal Workshop](https://www.youtube.com/live/0Jg1o9BFUBs?si=4g0okIn91QMIzew-) first.

## Branches
This branch demonstrates cross-chain verification bridging. For simple on-chain verification, check the `main` branch.

- `main`: on chain verification
- `backend-verification`: off chain/backend verification
- `hyperlane-example`: onchain verification w/ Hyperlane bridging

## 🌉 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  CELO SEPOLIA (Source Chain)                                 │
│                                                               │
│  ┌──────────────────────────────────────┐                   │
│  │  ProofOfHumanSender                   │                   │
│  │  - Inherits SelfVerificationRoot     │                   │
│  │  - Verifies users via Self Protocol  │                   │
│  │  - Automatic cross-chain bridging    │                   │
│  └────────────────┬─────────────────────┘                   │
│                   │                                           │
│                   │ Hyperlane Message                        │
│                   ▼                                           │
└───────────────────┼───────────────────────────────────────────┘
                    │
                    │
┌───────────────────┼───────────────────────────────────────────┐
│  BASE SEPOLIA (Destination Chain)                            │
│                   │                                           │
│                   ▼                                           │
│  ┌──────────────────────────────────────┐                   │
│  │  ProofOfHumanReceiver                 │                   │
│  │  - Receives Hyperlane messages       │                   │
│  │  - Stores verification data          │                   │
│  │  - Simple & gas-efficient            │                   │
│  └──────────────────────────────────────┘                   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Node.js 20+
- [Self Mobile App](https://self.xyz)
- Celo Sepolia wallet with testnet funds
- Base Sepolia wallet with testnet funds (for receiver deployment)

---

## Integration Steps

### Step 1: Repository Setup

```bash
# Clone the boilerplate repository
git clone https://github.com/selfxyz/self-integration-boilerplate.git
git switch hyperlane-example
cd workshop

# Install frontend dependencies
cd app
npm install

# Install contract dependencies
cd contracts
npm install
forge install foundry-rs/forge-std
```

### Step 2: Deploy Receiver Contract (Base Sepolia)

First, deploy the receiver contract on Base Sepolia:

```bash
# Create copy of env
cp .env.example .env
```

Edit `.env` with your Base Sepolia wallet:
```bash
# Your private key (with 0x prefix)
PRIVATE_KEY=0xyour_private_key_here
```

Deploy the receiver:
```bash
# Make script executable
chmod +x script/deploy-proof-of-human-receiver.sh

# Deploy receiver on Base Sepolia
./script/deploy-proof-of-human-receiver.sh
```

The script will:
- ✅ Deploy the receiver contract on Base Sepolia
- ✅ Display the contract address
- ✅ Provide instructions to update your `.env` files

**Save the `RECEIVER_ADDRESS` for the next step!**

### Step 3: Deploy Sender Contract (Celo Sepolia)

Add the receiver address to your `.env`:
```bash
# Add this line to .env
RECEIVER_ADDRESS=0x... # Address from Step 2

# Optional: Customize scope seed
SCOPE_SEED="proof-of-human-hyperlane"
```

Deploy the sender:
```bash
# Make script executable
chmod +x script/deploy-proof-of-human-sender.sh

# Deploy contract
./script/deploy-proof-of-human.sh
```

The script will:
- ✅ Deploy the sender contract on Celo Sepolia
- ✅ **Fund the contract with 0.01 CELO** (~10 automatic bridges)
- ✅ Display both contract addresses and contract balance
- ✅ Provide complete frontend `.env` configuration
- ✅ Show commands to automatically update your frontend `.env`

**The script provides all the configuration you need and funds automatic bridging!**

### Step 4: Frontend Configuration

Navigate to app folder
```bash
# Create copy of env
cp .env.example .env
# Edit .env with the values from the deployment script output
```

**Option B: Automatic Configuration (Recommended)**

The deployment script shows commands to automatically update your `.env`:
```bash
cd ../app
echo 'NEXT_PUBLIC_SELF_ENDPOINT=0x...' > .env
echo 'NEXT_PUBLIC_RECEIVER_ADDRESS=0x...' >> .env
echo 'NEXT_PUBLIC_SELF_APP_NAME="Self + Hyperlane Workshop"' >> .env
echo 'NEXT_PUBLIC_SELF_SCOPE_SEED="proof-of-human-hyperlane"' >> .env
```

Just copy and paste the commands from the deployment script output!

### Step 5: Start Development

```bash
# Start the Next.js development server
cd app
npm run dev
```

Visit `http://localhost:3000` to see your verification application!

---

## 🔄 How It Works

### Automatic Cross-Chain Bridging

1. **User verifies on Celo Sepolia** through your frontend
2. **Verification succeeds** → `customVerificationHook` is called
3. **Contract uses its balance** → Automatically pays Hyperlane gas & bridges to Base
4. **Data arrives on Base** → Receiver stores verification status (~2 minutes)

The deployment script automatically funds the sender contract with 0.01 CELO, enough for ~10 automatic bridges.

### Manual Bridging (Optional)

If the contract runs out of funds or you need to re-send:

```bash
# Fund the contract for more automatic bridges
cast send <SENDER_ADDRESS> --value 0.01ether --rpc-url celo-sepolia --private-key $PRIVATE_KEY

# Or manually bridge a specific verification
export SENDER_ADDRESS=0x...
export RECEIVER_ADDRESS=0x...
forge script script/SendVerificationCrossChain.s.sol:SendVerificationCrossChain \
  --rpc-url celo-sepolia \
  --broadcast
```

---

## 🛠️ Detailed Configuration

### Frontend SDK Configuration

The Self SDK is configured in your React components (`app/app/page.tsx`):

```javascript
import { SelfAppBuilder, countries } from '@selfxyz/qrcode';

const app = new SelfAppBuilder({
    version: 2,                    // Always use V2
    appName: process.env.NEXT_PUBLIC_SELF_APP_NAME,
    scope: process.env.NEXT_PUBLIC_SELF_SCOPE_SEED,
    endpoint: process.env.NEXT_PUBLIC_SELF_ENDPOINT,  // Your contract address (must be lowercase)
    logoBase64: "https://i.postimg.cc/mrmVf9hm/self.png", // Logo URL or base64
    userId: userId,                // User's wallet address or identifier
    endpointType: "staging_celo",  // "staging_celo" for testnet, "celo" for mainnet
    userIdType: "hex",             // "hex" for Ethereum addresses, "uuid" for UUIDs
    userDefinedData: "Hola Buenos Aires!!!",  // Optional custom data
    
    disclosures: {
        minimumAge: 18,
        excludedCountries: [countries.UNITED_STATES],
    }
}).build();
```

### Sender Contract (Celo Sepolia)

`ProofOfHumanSender` inherits from `SelfVerificationRoot`:

```solidity
contract ProofOfHumanSender is SelfVerificationRoot {
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        bytes memory userData
    ) internal override {
        // Store verification data
        verificationSuccessful = true;
        lastOutput = output;
        lastUserAddress = address(uint160(output.userIdentifier));

        emit VerificationCompleted(output, userData);
        
        // Automatically bridge if ETH was sent with verification
        if (address(this).balance > 0) {
            bytes memory message = abi.encode(
                bytes32(output.userIdentifier),
                lastUserAddress,
                userData,
                block.timestamp
            );
            
            bytes32 messageId = MAILBOX.dispatch{value: address(this).balance}(
                DESTINATION_DOMAIN,
                defaultRecipient.addressToBytes32(),
                message
            );
            
            emit VerificationSentCrossChain(messageId, defaultRecipient, lastUserAddress, bytes32(output.userIdentifier));
        }
    }
}
```

### Receiver Contract (Base Sepolia)

`ProofOfHumanReceiver` is a simple Hyperlane message receiver:

```solidity
contract ProofOfHumanReceiver is IMessageRecipient, Ownable {
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external override {
        // Verify caller is Hyperlane Mailbox
        if (msg.sender != address(MAILBOX)) revert NotMailbox();
        
        // Verify origin is Celo Sepolia
        if (_origin != SOURCE_DOMAIN) revert InvalidOrigin(_origin, SOURCE_DOMAIN);
        
        // Decode and store verification data
        (bytes32 userIdentifier, address userAddress, bytes memory userData, uint256 verifiedAt) 
            = abi.decode(_message, (bytes32, address, bytes, uint256));
        
        verifications[userAddress] = VerificationData({
            userIdentifier: userIdentifier,
            userAddress: userAddress,
            userData: userData,
            verifiedAt: verifiedAt,
            receivedAt: block.timestamp,
            exists: true,
            isVerified: true
        });
        
        emit VerificationReceived(userAddress, userIdentifier, block.timestamp);
    }
}
```

### Network Configuration

#### Celo Sepolia (Source Chain)
- **Chain ID**: 11142220
- **Identity Hub**: `0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74`
- **Hyperlane Mailbox**: `0xD0680F80F4f947968206806C2598Cbc5b6FE5b03`
- **RPC**: `https://forno.celo-sepolia.celo-testnet.org`
- **Explorer**: `https://celo-sepolia.blockscout.com/`

#### Base Sepolia (Destination Chain)
- **Chain ID**: 84532
- **Hyperlane Mailbox**: `0x6966b0E55883d49BFB24539356a2f8A673E02039`
- **RPC**: `https://sepolia.base.org`
- **Explorer**: `https://sepolia.basescan.org`

---

## 🧪 Testing

### Run Contract Tests

```bash
cd contracts
forge test -vv
```

All 23 tests should pass:
- `ProofOfHumanSender`: 8 tests
- `ProofOfHumanReceiver`: 11 tests  
- `HyperlaneCrossChain`: 3 tests

### Verify Cross-Chain Message

After a user verifies, check the message on Hyperlane Explorer:

```bash
# Get the message ID from transaction logs
cast logs --rpc-url celo-sepolia \
  --address <SENDER_ADDRESS> \
  --from-block <BLOCK_NUMBER>

# Track on Hyperlane Explorer
https://explorer.hyperlane.xyz/message/<MESSAGE_ID>
```

### Check Verification on Base

```bash
# Check if user is verified on Base Sepolia
cast call <RECEIVER_ADDRESS> \
  "isVerified(address)(bool)" \
  <USER_ADDRESS> \
  --rpc-url base-sepolia
```

---

## 📁 Project Structure

```
self-integration-example/
├── app/                                 # Next.js frontend application
│   ├── app/
│   │   ├── page.tsx              # QR code verification page
│   │   ├── verified/             # Success page
│   │   └── globals.css
│   └── .env.example
│
├── contracts/                    # Foundry contracts
│   ├── src/
│   │   ├── ProofOfHumanSender.sol      # Sender contract (Celo)
│   │   ├── ProofOfHumanReceiver.sol    # Receiver contract (Base)
│   │   ├── ProofOfHuman.sol            # Base implementation
│   │   └── IMailboxV3.sol              # Hyperlane interface
│   │
│   ├── script/
│   │   ├── Base.s.sol                   # Base script utilities
│   │   ├── DeployProofOfHuman.s.sol     # Foundry deployment script
│   │   └── deploy-proof-of-human.sh     # Automated deployment script
│   ├── lib/                             # Dependencies
│   │   ├── forge-std/                   # Foundry standard library
│   │   └── openzeppelin-contracts/      # OpenZeppelin contracts
│   ├── .env.example                     # Contract environment template
│   ├── foundry.toml                     # Foundry configuration
│   ├── package.json                     # Contract dependencies
│   │   ├── deploy-proof-of-human-receiver.sh   # Deploy receiver
│   │   ├── deploy-proof-of-human-sender.sh     # Deploy sender
│   │   ├── DeployProofOfHumanReceiver.s.sol
│   │   ├── DeployProofOfHumanSender.s.sol
│   │   └── SendVerificationCrossChain.s.sol    # Manual bridging
│   │
│   └── test/
│       ├── ProofOfHumanSender.t.sol
│       ├── ProofOfHumanReceiver.t.sol
│       └── HyperlaneCrossChain.t.sol
│
└── README.md                            # This file
```

---

## 🔗 Additional Resources

### Documentation
- [Self Protocol Docs](https://docs.self.xyz/) - Identity verification
- [Hyperlane Docs](https://docs.hyperlane.xyz/) - Cross-chain messaging
- [Contract Integration Guide](https://docs.self.xyz/contract-integration/basic-integration)

### Deployed Contracts (Example)
- **Sender (Celo Sepolia)**: `0x210cEb7F310197a3D4E83554086cCeD570314Ee4`
- **Receiver (Base Sepolia)**: `0x0690e42FA30BcC48Dd0bf8BF926654e6efDFee89`

### Self App
- [Self on iOS](https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710) - iOS App
- [Self on Android](https://play.google.com/store/apps/details?id=com.proofofpassportapp) - Android App