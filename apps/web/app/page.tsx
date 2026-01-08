"use client";

import { Button } from "@repo/ui/components/ui/button";
import { Textarea } from "@repo/ui/components/ui/textarea";

import { HelloArchitectAbi } from "@repo/contracts/abi";
import { type ExtractAbiEvent, type ExtractAbiFunction } from 'abitype';
import { useReadContract, useWriteContract } from "wagmi";
import { Address } from "@/lib/types";
import { useState, useEffect } from "react";

// Debug: Log the contract address
const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_HELLOARCHITECT_ADDRESS as `0x${string}`;
console.log("Contract Address:", CONTRACT_ADDRESS);
console.log("ABI:", HelloArchitectAbi);

export default function Home() {
  const [inputGreeting, setInputGreeting] = useState("");

  const { 
    data: greeting, 
    refetch, 
    isLoading: isReadLoading,
    error: readError,
    status: readStatus,
    fetchStatus: readFetchStatus,
    isError: isReadError,
  } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: HelloArchitectAbi,
    functionName: "getGreeting",
  });

  const { 
    data: hash, 
    writeContractAsync, 
    isPending: isWritePending,
    error: writeError,
  } = useWriteContract();

  const handleGetGreeting = async () => {
    console.log("Refetching greeting...");
    const result = await refetch();
    console.log("Refetch result:", result);
  };

  const handleSetGreeting = async () => {
    try {
      const hash = await writeContractAsync({
        address: process.env.NEXT_PUBLIC_HELLOARCHITECT_ADDRESS as `0x${string}`,
        abi: HelloArchitectAbi,
        functionName: "setGreeting",
        args: [inputGreeting],
      });
      console.log("Transaction hash:", hash);

      // Refetch greeting after successful write
      refetch();
    } catch (error) {
      console.error("Error setting greeting:", error);
    }
  };

  return (
    <div className="flex flex-col h-screen items-center justify-center gap-4">
      {/* Debug Panel */}
      <div className="fixed top-4 left-4 bg-black/80 text-white p-4 rounded-lg text-xs font-mono">
        <h3 className="font-bold mb-2">Debug Info</h3>
        <div>Contract: {CONTRACT_ADDRESS || "NOT SET!"}</div>
        <div>Read Status: {readStatus}</div>
        <div>Fetch Status: {readFetchStatus}</div>
        <div>Greeting Data: {JSON.stringify(greeting)}</div>
        {readError && (
          <div className="text-red-400 mt-2">
            Read Error: {readError.message}
          </div>
        )}
        {writeError && (
          <div className="text-red-400 mt-2">
            Write Error: {writeError.message}
          </div>
        )}
        {hash && <div className="text-green-400">TX Hash: {hash}</div>}
      </div>

      <div className="flex items-center gap-4">
        <Textarea 
          placeholder="Enter your greeting" 
          value={inputGreeting}
          onChange={(e) => setInputGreeting(e.target.value)}
        />
        <Button onClick={handleSetGreeting} disabled={isWritePending}>
          {isWritePending ? "Setting..." : "Set Greeting"}
        </Button>
        <Button onClick={handleGetGreeting} disabled={isReadLoading}>
          {isReadLoading ? "Loading..." : "Get Greeting"}
        </Button>
      </div>
      
      <p>{greeting ?? "Click button to load the greeting"}</p>
      
      {isReadError && (
        <p className="text-red-500">Error: {readError?.message}</p>
      )}
    </div>
  );
}
