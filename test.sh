hash="badcace35eca3975b86a7d744a198f996983b3f8f265644b0c0db50289070a24"
file="$1"

sed -i '' -e "s/96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f/$hash/" contracts/aggregators/Ethereum/libraries/EthereumUniswapV2Library.sol

npx hardhat test $file

sed -i '' -e "s/$hash/96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f/" contracts/aggregators/Ethereum/libraries/EthereumUniswapV2Library.sol
