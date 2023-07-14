hash="ef2e9f32eb5ae6f022210d17744636628e5e5ff16f328d46cbdd101e6a7ba545"
file="$1"

sed -i '' -e "s/96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f/$hash/" contracts/aggregators/Ethereum/libraries/EthereumUniswapV2Library.sol

npx hardhat test $file

sed -i '' -e "s/$hash/96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f/" contracts/aggregators/Ethereum/libraries/EthereumUniswapV2Library.sol
