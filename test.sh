sourceHash="96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"

testHash=$( npx hardhat test ./test/utils/init.ts )
testHash=${testHash#*0x}
testHash=${testHash:0:64}

file="$1"

sed -i '' -e "s/$sourceHash/$testHash/" contracts/aggregators/Ethereum/libraries/EthereumUniswapV2Library.sol

npx hardhat test $file

sed -i '' -e "s/$testHash/$sourceHash/" contracts/aggregators/Ethereum/libraries/EthereumUniswapV2Library.sol
