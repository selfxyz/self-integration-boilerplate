"use client";

import { useState, useEffect } from "react";
import Image from "next/image";
import styles from "./page.module.css";
import skeleton from "./skeleton.gif";
import { ethers } from "ethers";

const SENDER_CONTRACT = process.env.NEXT_PUBLIC_SELF_ENDPOINT || "";
const RECEIVER_CONTRACT = process.env.NEXT_PUBLIC_RECEIVER_ADDRESS || "";
const BASE_SEPOLIA_RPC = "https://sepolia.base.org";

// Simple ABI for verificationCount
const RECEIVER_ABI = [
	"function verificationCount() view returns (uint256)"
];

export default function HomePage() {
	const [bridgingStatus, setBridgingStatus] = useState<"pending" | "checking" | "completed" | "failed">("pending");
	const [verificationCount, setVerificationCount] = useState<number>(0);
	const [initialCount, setInitialCount] = useState<number | null>(null);
	const [checkCount, setCheckCount] = useState(0);

	// Check verification count on Base Sepolia
	useEffect(() => {
		if (!RECEIVER_CONTRACT || bridgingStatus === "completed") return;

		let intervalId: NodeJS.Timeout;
		let attempts = 0;
		const maxAttempts = 24; // Check for ~2 minutes (every 5 seconds)

		const checkVerificationCount = async () => {
			try {
				const provider = new ethers.JsonRpcProvider(BASE_SEPOLIA_RPC);
				const contract = new ethers.Contract(RECEIVER_CONTRACT, RECEIVER_ABI, provider);
				
				const count = await contract.verificationCount();
				const currentCount = Number(count);
				setVerificationCount(currentCount);
				
				// Store initial count on first check
				if (initialCount === null) {
					setInitialCount(currentCount);
					setBridgingStatus("checking");
				} else if (currentCount > initialCount) {
					// New verification received!
					setBridgingStatus("completed");
					clearInterval(intervalId);
				} else {
					setBridgingStatus("checking");
				}
				
				attempts++;
				setCheckCount(attempts);
				
				if (attempts >= maxAttempts && currentCount === initialCount) {
					setBridgingStatus("failed");
					clearInterval(intervalId);
				}
			} catch (error) {
				console.error("Error checking verification count:", error);
				setBridgingStatus("checking");
				attempts++;
				setCheckCount(attempts);
				
				if (attempts >= maxAttempts) {
					setBridgingStatus("failed");
					clearInterval(intervalId);
				}
			}
		};

		// Initial check
		checkVerificationCount();

		// Set up polling every 5 seconds
		intervalId = setInterval(checkVerificationCount, 5000);

		return () => clearInterval(intervalId);
	}, [bridgingStatus, initialCount]);

	const getStatusIcon = () => {
		switch (bridgingStatus) {
			case "completed":
				return "✅";
			case "checking":
				return "🔄";
			case "failed":
				return "⚠️";
			default:
				return "⏱️";
		}
	};

	const getStatusText = () => {
		switch (bridgingStatus) {
			case "completed":
				return `Cross-chain bridging successful! Total verifications: ${verificationCount}`;
			case "checking":
				return `Checking Base Sepolia... (attempt ${checkCount}) - Current count: ${verificationCount}`;
			case "failed":
				return "Bridging taking longer than expected. Check manually below.";
			default:
				return "Waiting for Hyperlane to bridge data...";
		}
	};
	return (
		<div className="flex flex-col items-center justify-center min-h-screen bg-gradient-to-br from-green-50 via-blue-50 to-purple-50 overflow-hidden p-4">
			<div className="bg-white rounded-2xl shadow-xl p-6 sm:p-8 max-w-2xl w-full">
				<div className="text-center mb-8">
					<div className="inline-block">
						<h1 className={styles.rotatingTitle}>Identity Verified!</h1>
						<div className="flex items-center justify-center gap-2 mt-2">
							<span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
								✓ Celo Sepolia
							</span>
						</div>
					</div>
				</div>

				<div className="text-center mb-8">
					<Image
						src={skeleton}
						alt="Success animation"
						width={250}
						height={250}
						priority
					/>
				</div>

				{/* Cross-chain bridging info */}
				<div className={`border-2 rounded-xl p-4 mb-6 ${
					bridgingStatus === "completed" ? "bg-green-50 border-green-200" :
					bridgingStatus === "failed" ? "bg-yellow-50 border-yellow-200" :
					"bg-blue-50 border-blue-200"
				}`}>
					<h2 className={`text-lg font-semibold mb-3 flex items-center gap-2 ${
						bridgingStatus === "completed" ? "text-green-900" :
						bridgingStatus === "failed" ? "text-yellow-900" :
						"text-blue-900"
					}`}>
						🌉 Cross-Chain Bridging Status
					</h2>
					<div className="space-y-2 text-sm">
						<div className="flex items-center gap-2">
							<span className="text-xl">✅</span>
							<span className={bridgingStatus === "completed" ? "text-green-800" : "text-blue-800"}>
								Verification recorded on Celo Sepolia
							</span>
						</div>
						<div className="flex items-center gap-2">
							<span className="text-xl">{getStatusIcon()}</span>
							<span className={
								bridgingStatus === "completed" ? "text-green-800 font-semibold" :
								bridgingStatus === "failed" ? "text-yellow-800" :
								"text-blue-800"
							}>
								{getStatusText()}
							</span>
						</div>
						{bridgingStatus === "pending" || bridgingStatus === "checking" ? (
							<div className="flex items-center gap-2">
								<span className="text-xl">⏱️</span>
								<span className="text-blue-700">This usually takes ~2 minutes (checking every 5s)</span>
							</div>
						) : bridgingStatus === "completed" ? (
							<div className="flex items-center gap-2">
								<span className="text-xl">🎉</span>
								<span className="text-green-800 font-semibold">
									Disclosure proof data successfully bridged from Celo to Base!
								</span>
							</div>
						) : null}
					</div>
					
					<div className="mt-3 pt-3 border-t border-opacity-30 border-gray-400">
						<p className="text-xs text-gray-600">Monitoring receiver contract:</p>
						<code className="block text-xs mt-1 p-1 bg-white rounded break-all text-blue-700">
							{RECEIVER_CONTRACT}
						</code>
						{initialCount !== null && (
							<p className="text-xs text-gray-500 mt-1">
								Started with {initialCount} verification(s), now at {verificationCount}
							</p>
						)}
					</div>
				</div>

				{/* Action Items */}
				<div className="space-y-3">
					<h3 className="font-semibold text-gray-800 text-center">Check your verification status:</h3>
					
					<a
						href={`https://celo-sepolia.blockscout.com/address/${SENDER_CONTRACT}`}
						target="_blank"
						rel="noopener noreferrer"
						className="block w-full bg-green-600 hover:bg-green-700 text-white font-medium py-3 px-4 rounded-lg text-center transition-colors"
					>
						View on Celo Sepolia →
					</a>

					<a
						href={`https://explorer.hyperlane.xyz/?search=${SENDER_CONTRACT}`}
						target="_blank"
						rel="noopener noreferrer"
						className="block w-full bg-purple-600 hover:bg-purple-700 text-white font-medium py-3 px-4 rounded-lg text-center transition-colors"
					>
						Track Messages on Hyperlane →
					</a>
					<p className="text-xs text-gray-500 text-center mt-2">
						Search for messages from the sender contract
					</p>

					<a
						href={`https://sepolia.basescan.org/address/${RECEIVER_CONTRACT}`}
						target="_blank"
						rel="noopener noreferrer"
						className="block w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-4 rounded-lg text-center transition-colors"
					>
						Check on Base Sepolia →
					</a>
				</div>

				{/* Additional Info */}
				<div className="mt-6 p-4 bg-gray-50 rounded-lg">
					<p className="text-xs text-gray-600 text-center mb-2">
						<strong>What was bridged:</strong>
					</p>
					<ul className="text-xs text-gray-700 space-y-1 text-left max-w-md mx-auto">
						<li>✓ User identifier from disclosure proof</li>
						<li>✓ Verification timestamp</li>
						<li>✓ Custom user data</li>
						<li>✓ Proof of identity verification from Self Protocol</li>
					</ul>
					<p className="text-xs text-gray-500 text-center mt-3">
						View the receiver contract on <a href={`https://sepolia.basescan.org/address/${RECEIVER_CONTRACT}#readContract`} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">BaseScan</a>
					</p>
				</div>

				<div className="mt-6 text-center">
					<a
						href="/"
						className="text-sm text-blue-600 hover:text-blue-800 underline"
					>
						← Back to verification page
					</a>
				</div>
			</div>
		</div>
	);
}
