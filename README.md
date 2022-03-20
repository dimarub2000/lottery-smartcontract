# lottery-smartcontract

1. Install Brownie
```
python3 -m pip install --user pipx
python3 -m pipx ensurepath
# restart your terminal
pipx install eth-brownie
```
2. Fill .env file with required tokens ([WEB3_INFURA_PROJECT_ID](https://infura.io/), [ETHERSCAN_TOKEN](https://etherscan.io/))


4. Deploy on Kovan
```
brownie run scripts/deploy_lottery.py --network kovan
```
