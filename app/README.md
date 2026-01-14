# Self Integration Example Front End

This project demonstrates integration with the [Self Protocol](https://self.xyz/) for identity verification in a Next.js application. Users can verify their identity using the Self mobile app by scanning a QR code.

## Features

- QR code generation for Self Protocol integration
- Identity verification flow
- Customizable identity verification parameters

## Prerequisites

- Node.js 20.x or higher
- NPM or Yarn
- Self Protocol App [iOS](https://apps.apple.com/us/app/self-zk/id6478563710) or [Android](https://play.google.com/store/apps/details?id=com.proofofpassportapp&pli=1) installed on your mobile device
- A public endpoint for the verification callback (can use [ngrok](https://ngrok.com/) for local development)

## Environment Setup

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Configure the environment variables:
   - `NEXT_PUBLIC_SELF_ENDPOINT`: Set to your verification endpoint (your deployed smart contract address if doing on chain verificagion, or your backend HTTPS endpoint if you are doing offchain verification (e.g., ngrok URL))
   - `NEXT_PUBLIC_SELF_APP_NAME`: Your application name (default: "Self Workshop")
   - `NEXT_PUBLIC_SELF_SCOPE_SEED`: Seed used to generate your scope (default: "self-workshop")

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   ```

2A. Offchain Verification - Local Development (using ngrok):
   ```bash
   npx ngrok http 3000
   ```
   - Copy the public URL (e.g., `https://abc123.ngrok.io`) and set it as `NEXT_PUBLIC_SELF_ENDPOINT` in your `.env` file.
   - Set `NEXT_PUBLIC_SELF_SCOPE_SEED` to match your backend's scope seed.
   - Set the `endpointType` in `page.tsx` to `"https"` for mainnet or `"staging_https"` for testnet

2B. Offchain Verification - Production (deployed backend):
   - Deploy your backend verification server to a cloud provider (Vercel, Railway, AWS, etc.)
   - Copy your deployed backend's public URL (e.g., `https://your-api.vercel.app`)
   - Set it as `NEXT_PUBLIC_SELF_ENDPOINT` in your `.env` file
   - Set `NEXT_PUBLIC_SELF_SCOPE_SEED` to match your backend's scope seed
   - Set the `endpointType` in `page.tsx` to `"https"` for mainnet or `"staging_https"` for testnet

2C. Onchain Verification (smart contract):
   - Navigate to the contracts folder and run the deployment script:
   ```bash
   cd ../contracts
   ./script/deploy-proof-of-human.sh
   ```
   - Copy the deployed contract address (**must be lowercase**) and set it as `NEXT_PUBLIC_SELF_ENDPOINT` in your `.env` file
   - Copy the scope seed value and set it as `NEXT_PUBLIC_SELF_SCOPE_SEED` in your `.env` file
   - Set the `endpointType` in `page.tsx` to `"celo"` for mainnet (real ID documents) or `"staging_celo"` for testnet (mock ID documents)

3. Run the development server:
   ```bash
   npm run dev
   # or
   yarn dev
   ```

4. Open [http://localhost:3000](http://localhost:3000) with your browser to see the application.

## How It Works

1. When users visit the homepage, a unique QR code is generated using the Self Protocol.
2. Users scan this QR code with their Self app.
3. The Self app prompts users to share their identity information.
4. After successful verification, users are redirected to the `/verified` page.

## Customization

The application can be customized by modifying the following files:

- `src/app/page.tsx`: Frontend Self Protocol integration
  - Customize the identity requirements in the `disclosures` section
  - Modify the success callback behavior