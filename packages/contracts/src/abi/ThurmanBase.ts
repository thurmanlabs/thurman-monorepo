// Generated from out/ThurmanBase.sol/ThurmanBase.json
export const ThurmanBaseAbi = [
  {
    "type": "function",
    "name": "platformConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IPlatformConfig"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "roleRegistry",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IRoleRegistry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "error",
    "name": "NotAuthorized",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "role",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "PlatformPaused",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
