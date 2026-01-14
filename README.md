# Self Protocol Boilerplate Example

Learn to build privacy-preserving identity verification with [Self Protocol](https://self.xyz/) - from frontend QR codes to backend API verification.

> 📺 **New to Self?** Watch the [ETHGlobal Workshop](https://www.loom.com/share/8a6d116a5f66415998a496f06fefdc23) first.

## Branches
This main branch of the repo contains an example of onchain verification. If you would like to see an example with offchain/backend verification, please check out the 'backend-verification' branch.

- `main`: on chain verification
- `backend-verification`: off chain/backend verification
- `hyperlane-example`: onchain verification w/ Hyperlane bridging

## Prerequisites

- Node.js 20+
- [Self Mobile App](https://self.xyz)
- [ngrok](https://ngrok.com/) (for local development)

---

## Integration Steps

### Step 1: Repository Setup

```bash
# Clone the workshop repository
git clone <repository-url>
cd workshop/app

# Install dependencies
npm install
```

### Step 2: Setup ngrok Tunnel

For local development, you need a publicly accessible endpoint. Start ngrok in a separate terminal:

```bash
# Install ngrok if you haven't already
# macOS: brew install ngrok
# Or download from: https://ngrok.com/download

# Start ngrok tunnel to port 3000
ngrok http 3000
```

Keep ngrok running and note the URL (e.g., `https://abc123.ngrok-free.app`).

> **💡 Tip**: ngrok creates a tunnel so the Self app relayers can reach your local backend API endpoint at `/api/verify`.

### Step 3: Frontend Configuration

Configure the application:

```bash
# Create copy of env
cp .env.example .env
```

Edit `.env` with your ngrok URL from Step 2:
```bash
# Your ngrok URL from Step 2 + /api/verify
NEXT_PUBLIC_SELF_ENDPOINT=https://your-ngrok-url.ngrok-free.app/api/verify

# App configuration
NEXT_PUBLIC_SELF_APP_NAME="Self Workshop"
NEXT_PUBLIC_SELF_SCOPE_SEED="self-workshop"
```

> **⚠️ Important**: The endpoint must be publicly accessible. Update it each time you restart ngrok.

### Step 4: Start Development

```bash
# Start the Next.js development server
cd app
npm run dev
```

Visit `http://localhost:3000` to see your verification application!

**Test the flow:**
1. Open the app at `http://localhost:3000`
2. Scan the QR code with the Self mobile app
3. Complete verification on your phone
4. The backend API will verify the proof and return results
5. You'll be redirected to the success page

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
    endpoint: process.env.NEXT_PUBLIC_SELF_ENDPOINT,  // Your ngrok URL + /api/verify
    logoBase64: "https://i.postimg.cc/mrmVf9hm/self.png", // Logo URL or base64
    userId: userId,                // User's identifier (Ethereum address)
    endpointType: "staging_https", // "staging_https" for testnet backend, "https" for mainnet
    userIdType: "hex",             // "hex" for Ethereum addresses
    userDefinedData: "Hola Buenos Aires!!!",  // Optional custom data
    
    disclosures: {
        // Verification requirements (must match your backend config)
        minimumAge: 18,
        excludedCountries: [countries.UNITED_STATES],  // Use country constants
        // ofac: true,               // Optional: OFAC compliance checking
        
        // Optional disclosures (uncomment to request):
        // name: true,
        // issuing_state: true,
        // nationality: true,
        // date_of_birth: true,
        // passport_number: true,
        // gender: true,
        // expiry_date: true,
    }
}).build();
```

### Backend API Configuration

Your backend verification endpoint is at `app/api/verify/route.ts`:

```typescript
import { NextResponse } from "next/server";
import { SelfBackendVerifier, AllIds, DefaultConfigStore } from "@selfxyz/core";

// Initialize the verifier (runs once when server starts)
const selfBackendVerifier = new SelfBackendVerifier(
  process.env.NEXT_PUBLIC_SELF_SCOPE_SEED || "self-workshop",
  process.env.NEXT_PUBLIC_SELF_ENDPOINT || "http://localhost:3000/api/verify",
  true, // mockPassport: true = staging/testnet, false = mainnet
  AllIds,
  new DefaultConfigStore({
    minimumAge: 18,
    excludedCountries: ["USA"],
    ofac: false,
  }),
  "hex" // userIdentifierType must match frontend userIdType
);

export async function POST(req: Request) {
  try {
    const { attestationId, proof, publicSignals, userContextData } = await req.json();

    // Verify all required fields are present
    if (!proof || !publicSignals || !attestationId || !userContextData) {
      return NextResponse.json({
        message: "Proof, publicSignals, attestationId and userContextData are required",
      }, { status: 200 });
    }

    // Verify the proof
    const result = await selfBackendVerifier.verify(
      attestationId,
      proof,
      publicSignals,
      userContextData
    );

    // Check if verification was successful
    if (result.isValidDetails.isValid) {
      return NextResponse.json({
        status: "success",
        result: true,
        credentialSubject: result.discloseOutput,
      });
    } else {
      return NextResponse.json({
        status: "error",
        result: false,
        reason: "Verification failed",
        details: result.isValidDetails,
      }, { status: 200 });
    }
  } catch (error) {
    return NextResponse.json({
      status: "error",
      result: false,
      reason: error instanceof Error ? error.message : "Unknown error",
    }, { status: 200 });
  }
}
```

**Important**: Frontend `disclosures` must match backend `DefaultConfigStore` configuration.

### Verification Modes

#### Staging/Testnet (`mockPassport: true`)
- **Use for**: Development and testing
- **Supports**: Mock passports from Self app
- **Hub Address**: `0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74`
- **Network**: Celo Sepolia testnet
- **RPC**: `https://forno.celo-sepolia.celo-testnet.org`

#### Production/Mainnet (`mockPassport: false`)
- **Use for**: Production deployments
- **Supports**: Real passport verification only
- **Hub Address**: `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF`
- **Network**: Celo Mainnet
- **RPC**: `https://forno.celo.org`

> **Note**: The backend verifier connects to Celo blockchain to verify merkle roots and registry contracts, but verification logic runs on your server.

---

### Getting Help

- 📱 **Telegram Community**: [Self Protocol Builders Group](https://t.me/selfprotocolbuilder)
- 📖 **Documentation**: [docs.self.xyz](https://docs.self.xyz)
- 🎥 **Workshop Video**: [ETHGlobal Cannes](https://www.loom.com/share/8a6d116a5f66415998a496f06fefdc23)

---

## 📁 Project Structure

```
self-integration-example/
└── app/                                 # Next.js application
    ├── app/
    │   ├── api/
    │   │   └── verify/
    │   │       └── route.ts             # Backend verification API endpoint
    │   ├── page.tsx                     # Main QR code page with Self SDK integration
    │   ├── layout.tsx                   # Root layout with metadata
    │   ├── globals.css                  # Global styles
    │   └── verified/
    │       ├── page.tsx                 # Success page after verification
    │       └── page.module.css          # Success page styles
    ├── .env.example                     # Environment template
    ├── package.json                     # Dependencies
    ├── tailwind.config.ts               # Tailwind CSS configuration
    └── README.md                        # Documentation
```

---

## 🔗 Additional Resources

### Documentation
- [Self Protocol Docs](https://docs.self.xyz/) - Complete protocol documentation
- [Backend Integration Guide](https://docs.self.xyz/backend-integration/basic-integration) - Backend verification specifics
- [SelfBackendVerifier API](https://docs.self.xyz/backend-integration/selfbackendverifier-api-reference) - Backend API reference
- [Frontend SDK Reference](https://docs.self.xyz/use-self/quickstart) - Frontend integration details
- [Disclosure Proofs](https://docs.self.xyz/use-self/disclosures) - Available verification options

### Self App
- [Self on iOS](https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710) - iOS App
- [Self on Android](https://play.google.com/store/apps/details?id=com.proofofpassportapp) - Android App