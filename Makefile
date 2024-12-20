-include .env

.PHONY: all test deploy

deploy-anvil:
	@forge script script/DeployLottery.s.sol --rpc-url $(LOCAL_RPC_URL) --account anvil_account --broadcast
