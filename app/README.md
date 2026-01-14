# Self + Hyperlane Integration Example Front End

This project demonstrates cross-chain identity verification using [Self Protocol](https://self.xyz/) for identity verification on Celo and [Hyperlane](https://hyperlane.xyz/) for bridging verification data to Base.

## Features

- 🔐 Identity verification via Self Protocol on Celo Sepolia
- 🌉 Automatic cross-chain bridging via Hyperlane to Base Sepolia (~2 minutes)
- 📱 Mobile-friendly QR code interface
- 🔄 **Real-time verification status tracking on Base** - polls every 5 seconds
- 📊 Live bridging status with visual feedback
- 🔗 Dynamic links to block explorers and Hyperlane message tracking
- ⏱️ Automatic detection when verification arrives on Base

## Prerequisites

- Node.js 20.x or higher
- NPM or Yarn
- Self Protocol App installed on your mobile device:
  - [iOS](https://apps.apple.com/us/app/self-zk/id6478563710)
  - [Android](https://play.google.com/store/apps/details?id=com.proofofpassportapp)
- Deployed contracts:
  - ProofOfHumanSender on Celo Sepolia
  - ProofOfHumanReceiver on Base Sepolia

## Environment Setup

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Configure the environment variables:
   ```bash
   # Sender contract address (deployed on Celo Sepolia) - MUST BE LOWERCASE
   NEXT_PUBLIC_SELF_ENDPOINT=0xyour_sender_contract_address

   # Receiver contract address (deployed on Base Sepolia) - MUST BE LOWERCASE
   NEXT_PUBLIC_RECEIVER_ADDRESS=0xyour_receiver_contract_address

   # Application name
   NEXT_PUBLIC_SELF_APP_NAME="Self + Hyperlane Workshop"

   # Scope seed (must match deployment)
   NEXT_PUBLIC_SELF_SCOPE_SEED="proof-of-human-hyperlane"
   ```

   **Important:** Contract addresses MUST be lowercase to match on-chain scope calculations.

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   ```

2. Make sure you have deployed both contracts:
   ```bash
   # From the contracts directory:
   cd ../contracts
   
   # Deploy receiver on Base Sepolia first:
   ./script/deploy-proof-of-human-receiver.sh
   
   # Then deploy sender on Celo Sepolia:
   ./script/deploy-proof-of-human-sender.sh
   ```

3. Update your `.env` file with the deployed contract addresses.

4. Run the development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) to see the application.

## How It Works

### Verification Flow

1. **User scans QR code** with Self Protocol mobile app
2. **Verification happens on Celo Sepolia** via ProofOfHumanSender contract
3. **Automatic bridging** - Verification data is sent cross-chain via Hyperlane
4. **Data arrives on Base** - ProofOfHumanReceiver stores verification status
5. **User sees success page** with links to track the cross-chain message

### Architecture

```
User Mobile App
      ↓
[Scan QR Code]
      ↓
Celo Sepolia
├─ ProofOfHumanSender
├─ SelfVerificationRoot
└─ customVerificationHook
      ↓
   Hyperlane
   (1-2 min)
      ↓
Base Sepolia
└─ ProofOfHumanReceiver
```

## Key Components

### Main Page (`app/page.tsx`)
- QR code generation and display
- Cross-chain flow explanation
- Contract address display
- Links to block explorers

### Success Page (`app/verified/page.tsx`)
- Verification confirmation
- **Real-time cross-chain bridging status** ✨
  - Automatically polls Base Sepolia every 5 seconds
  - Shows live status: Pending → Checking → Completed
  - Completes in ~2 minutes
- Direct links to:
  - Celo Sepolia Explorer (source transaction)
  - Hyperlane Explorer (message tracking by sender address)
  - Base Sepolia Explorer (destination contract)

## Customization

### Modify Verification Requirements

Edit `app/page.tsx`, `disclosures` section:

```javascript
disclosures: { 
  minimumAge: 18,
  excludedCountries: [countries.UNITED_STATES],
  // Optional fields:
  // name: true,
  // issuing_state: true,
  // nationality: true,
  // date_of_birth: true,
}
```

### Change Networks

To deploy on mainnet:
- Use Celo Mainnet for sender
- Use Base Mainnet for receiver
- Update `endpointType` from `"staging_celo"` to `"celo"`
- Update contract addresses and RPC URLs

## Tracking Verification

### Check on Celo Sepolia (Source)
```bash
cast call <SENDER_ADDRESS> \
  "verificationSuccessful()(bool)" \
  --rpc-url https://forno.celo-sepolia.celo-testnet.org
```

### Track on Hyperlane
Visit: https://explorer.hyperlane.xyz

### Check on Base Sepolia (Destination)
```bash
cast call <RECEIVER_ADDRESS> \
  "isVerified(address)(bool)" \
  <USER_ADDRESS> \
  --rpc-url https://sepolia.base.org
```

## Troubleshooting

### QR Code Not Loading
- Check that `NEXT_PUBLIC_SELF_ENDPOINT` is set and lowercase
- Verify contract is deployed on Celo Sepolia
- Ensure `NEXT_PUBLIC_SELF_SCOPE_SEED` matches deployment

### Verification Not Bridging
- Automatic bridging requires ETH sent with verification transaction
- Check Hyperlane Explorer for message status
- Verify receiver contract is deployed on Base Sepolia
- Try manual bridging using the SendVerificationCrossChain script

### Environment Variables Not Loading
- Environment variables must start with `NEXT_PUBLIC_` to be accessible in client-side code
- Restart the dev server after changing `.env`

## Resources

- [Self Protocol Docs](https://docs.self.xyz/)
- [Hyperlane Docs](https://docs.hyperlane.xyz/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Telegram Support](https://t.me/selfprotocolbuilder)

## License

MIT
