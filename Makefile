-include .env

build:
	forge build

test:
	forge test

deploy-anvil:
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url http://127.0.0.1:8545 --broadcast --account TestKey

install: 
	forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url https://eth-sepolia.g.alchemy.com/v2/SpNLu8QnfuaXgpmqHVAgauoMF0uY_L96 --account default --broadcast

