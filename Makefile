-include .env

build:
	forge build

test:
	forge test

deploy-anvil:
	forge script script/DeployRaffle.s.sol --rpc-url localhost:8545 --private-key $(PRIVATE_KEY) --broadcast


