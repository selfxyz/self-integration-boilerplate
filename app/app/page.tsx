"use client";

import React, { useState, useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import {
  SelfQRcodeWrapper,
  SelfAppBuilder,
  type SelfApp,
  countries, 
  getUniversalLink,
} from "@selfxyz/qrcode";
import { ethers } from "ethers";

// Contract addresses for cross-chain verification
const SENDER_CONTRACT = process.env.NEXT_PUBLIC_SELF_ENDPOINT || "";
const RECEIVER_CONTRACT = process.env.NEXT_PUBLIC_RECEIVER_ADDRESS || "";

export default function Home() {
  const router = useRouter();
  const [linkCopied, setLinkCopied] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState("");
  const [selfApp, setSelfApp] = useState<SelfApp | null>(null);
  const [universalLink, setUniversalLink] = useState("");
  // Use a demo address to demonstrate cross-chain bridging
  const [userId] = useState("0x1234567890123456789012345678901234567890");
  const [showInfo, setShowInfo] = useState(false);
  // Use useMemo to cache the array to avoid creating a new array on each render
  const excludedCountries = useMemo(() => [countries.UNITED_STATES], []);

  // Use useEffect to ensure code only executes on the client side
  useEffect(() => {
    try {
      const app = new SelfAppBuilder({
        version: 2,
        appName: process.env.NEXT_PUBLIC_SELF_APP_NAME,
        scope: process.env.NEXT_PUBLIC_SELF_SCOPE_SEED,
        endpoint: `${process.env.NEXT_PUBLIC_SELF_ENDPOINT}`,
        logoBase64:
          "https://i.postimg.cc/mrmVf9hm/self.png", // url of a png image, base64 is accepted but not recommended
        userId: userId,
        endpointType: "staging_celo",
          // [Onchain Verification] "celo" for mainnet smart contract ,
          // [Onchain Verification] "staging_celo" for testnet smart contract,
          // [Offchain Verification] "https" mainnet https endpoint,
          // [Offchain Verification] "staging_https" for testnet https endpoint
        userIdType: "hex", // use 'hex' for ethereum address or 'uuid' for uuidv4
        userDefinedData: "Cross-chain verification via Hyperlane",
        
        // [DEEPLINK CALLBACK] Uncomment to automatically redirect user to your app after verification
        //deeplinkCallback: `your-app-deeplink-url`,
        
        disclosures: { 
          // What you want to verify from users identity:
          minimumAge: 18,
          // ofac: true,
          excludedCountries: excludedCountries,
          
          // What you want users to reveal:
          // name: false,
          // issuing_state: true,
          // nationality: true,
          // date_of_birth: true,
          // passport_number: false,
          // gender: true,
          // expiry_date: false,
        }
      }).build();

      setSelfApp(app);
      setUniversalLink(getUniversalLink(app));
    } catch (error) {
      console.error("Failed to initialize Self app:", error);
    }
  }, [excludedCountries, userId]);

  const displayToast = (message: string) => {
    setToastMessage(message);
    setShowToast(true);
    setTimeout(() => setShowToast(false), 3000);
  };

  const copyToClipboard = () => {
    if (!universalLink) return;

    navigator.clipboard
      .writeText(universalLink)
      .then(() => {
        setLinkCopied(true);
        displayToast("Universal link copied to clipboard!");
        setTimeout(() => setLinkCopied(false), 2000);
      })
      .catch((err) => {
        console.error("Failed to copy text: ", err);
        displayToast("Failed to copy link");
      });
  };

  const openSelfApp = () => {
    if (!universalLink) return;

    window.open(universalLink, "_blank");
    displayToast("Opening Self App...");
  };

  const handleSuccessfulVerification = () => {
    displayToast("Verification successful! Bridging cross-chain...");
    setTimeout(() => {
      router.push("/verified");
    }, 1500);
  };

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-blue-50 via-purple-50 to-pink-50 flex flex-col items-center justify-center p-4 sm:p-6 md:p-8">
      {/* Header */}
      <div className="mb-6 md:mb-8 text-center max-w-2xl">
        <h1 className="text-2xl sm:text-3xl font-bold mb-2 text-gray-800">
          {process.env.NEXT_PUBLIC_SELF_APP_NAME || "Self + Hyperlane Workshop"}
        </h1>
        <p className="text-sm sm:text-base text-gray-600 px-2 mb-3">
          Verify on Celo Sepolia, use on Base Sepolia
        </p>
        <div className="flex items-center justify-center gap-2 text-xs text-gray-500">
          <span className="px-2 py-1 bg-green-100 text-green-700 rounded">Celo ✓</span>
          <span>→</span>
          <span className="px-2 py-1 bg-blue-100 text-blue-700 rounded">Hyperlane</span>
          <span>→</span>
          <span className="px-2 py-1 bg-purple-100 text-purple-700 rounded">Base</span>
        </div>
      </div>

      {/* Main content */}
      <div className="bg-white rounded-xl shadow-lg p-4 sm:p-6 w-full max-w-xs sm:max-w-sm md:max-w-md mx-auto">
        {/* Info Banner */}
        <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <div className="flex items-start gap-2">
            <span className="text-blue-600 text-xl">ℹ️</span>
            <div className="flex-1">
              <p className="text-xs text-blue-900 font-medium">Cross-Chain Verification</p>
              <p className="text-xs text-blue-700 mt-1">
                Your identity will be verified on Celo Sepolia and automatically bridged to Base Sepolia via Hyperlane.
              </p>
              <button
                onClick={() => setShowInfo(!showInfo)}
                className="text-xs text-blue-600 hover:text-blue-800 mt-1 underline"
              >
                {showInfo ? "Hide" : "Show"} details
              </button>
            </div>
          </div>
          
          {showInfo && (
            <div className="mt-3 pt-3 border-t border-blue-200 space-y-2">
              <div className="text-xs">
                <span className="font-semibold text-blue-900">Sender (Celo Sepolia):</span>
                <code className="block mt-1 p-1 bg-white rounded text-blue-700 break-all">
                  {SENDER_CONTRACT}
                </code>
              </div>
              <div className="text-xs">
                <span className="font-semibold text-blue-900">Receiver (Base Sepolia):</span>
                <code className="block mt-1 p-1 bg-white rounded text-blue-700 break-all">
                  {RECEIVER_CONTRACT}
                </code>
              </div>
              <div className="text-xs text-blue-700 mt-2">
                <p className="font-semibold">How it works:</p>
                <ol className="list-decimal list-inside space-y-1 mt-1">
                  <li>Scan QR & verify with Self Protocol</li>
                  <li>Verification recorded on Celo Sepolia</li>
                  <li>Data automatically bridges to Base via Hyperlane</li>
                  <li>Your verified status is available on Base!</li>
                </ol>
              </div>
            </div>
          )}
        </div>

        <div className="flex justify-center mb-4 sm:mb-6">
          {selfApp ? (
            <SelfQRcodeWrapper
              selfApp={selfApp}
              onSuccess={handleSuccessfulVerification}
              onError={() => {
                displayToast("Error: Failed to verify identity");
              }}
            />
          ) : (
            <div className="w-[256px] h-[256px] bg-gray-200 animate-pulse flex items-center justify-center">
              <p className="text-gray-500 text-sm">Loading QR Code...</p>
            </div>
          )}
        </div>

        <div className="flex flex-col sm:flex-row gap-2 sm:space-x-2 mb-4 sm:mb-6">
          <button
            type="button"
            onClick={copyToClipboard}
            disabled={!universalLink}
            className="flex-1 bg-gray-800 hover:bg-gray-700 transition-colors text-white p-2 rounded-md text-sm sm:text-base disabled:bg-gray-400 disabled:cursor-not-allowed"
          >
            {linkCopied ? "Copied!" : "Copy Universal Link"}
          </button>

          <button
            type="button"
            onClick={openSelfApp}
            disabled={!universalLink}
            className="flex-1 bg-blue-600 hover:bg-blue-500 transition-colors text-white p-2 rounded-md text-sm sm:text-base mt-2 sm:mt-0 disabled:bg-blue-300 disabled:cursor-not-allowed"
          >
            Open Self App
          </button>


        </div>
        <div className="flex flex-col items-center gap-2 mt-2">
          <span className="text-gray-500 text-xs uppercase tracking-wide">Demo Mode</span>
          <div className="bg-blue-50 rounded-md px-3 py-2 w-full text-center text-xs text-blue-700 border border-blue-200">
            This demo bridges disclosure proof data from Celo to Base via Hyperlane
          </div>
        </div>

        {/* Useful Links */}
        <div className="mt-4 pt-4 border-t border-gray-200">
          <p className="text-xs text-gray-600 text-center mb-2">Track your verification:</p>
          <div className="flex flex-col gap-2">
            <a
              href="https://celo-sepolia.blockscout.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-blue-600 hover:text-blue-800 text-center underline"
            >
              Celo Sepolia Explorer →
            </a>
            <a
              href={`https://explorer.hyperlane.xyz/?search=${SENDER_CONTRACT}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-purple-600 hover:text-purple-800 text-center underline"
            >
              Hyperlane Explorer →
            </a>
            <a
              href="https://sepolia.basescan.org"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-indigo-600 hover:text-indigo-800 text-center underline"
            >
              Base Sepolia Explorer →
            </a>
          </div>
        </div>

        {/* Toast notification */}
        {showToast && (
          <div className="fixed bottom-4 right-4 bg-gray-800 text-white py-2 px-4 rounded shadow-lg animate-fade-in text-sm">
            {toastMessage}
          </div>
        )}
      </div>
    </div>
  );
}
