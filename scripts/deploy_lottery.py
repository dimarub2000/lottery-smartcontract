from brownie import Lottery, accounts, config

def deploy_lottery(network):
    account = accounts.add(config["wallets"]["from_key"])
    lottery = Lottery.deploy(
        config["networks"][network]["vrf_coordinator"],
        config["networks"][network]["link_token"],
        config["networks"][network]["fee"],
        config["networks"][network]["keyhash"],
        config["networks"][network]["update_interval"],
        {"from": account},
        publish_source=config["networks"][network].get("verify", False),
    )
    print("Deployed lottery!")
    return lottery

def main():
    deploy_lottery('kovan')
