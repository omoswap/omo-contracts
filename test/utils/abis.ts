export const tokenMessenger = [
    {
        inputs: [
            { internalType: "uint256", name: "amount", type: "uint256" },
            { internalType: "uint32", name: "destinationDomain", type: "uint32" },
            { internalType: "bytes32", name: "targetBridge", type: "bytes32" },
            { internalType: "address", name: "token", type: "address" },
            { internalType: "bytes32", name: "targetBridge", type: "bytes32" },
        ],
        name: "depositForBurnWithCaller",
        outputs: [{ internalType: "uint64", name: "nonce", type: "uint64" }],
        stateMutability: "nonpayable",
        type: "function",
    },
    {
        inputs: [],
        name: "localMessageTransmitter",
        outputs: [
            {
                internalType: "contract IMessageTransmitter",
                name: "",
                type: "address",
            },
        ],
        stateMutability: "view",
        type: "function",
    },
];
