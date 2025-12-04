# FlashLoaner

Modernized FlashLoaner example contracts with Foundry. The project demonstrates how a Uniswap V2
flash swap callback can route liquidity through another AMM and capture any profit while repaying
the originating pair.

## Getting started

1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation). Once `forge` is
   available, install dependencies:

   ```bash
   forge install
   ```

2. Copy `.env.example` to `.env` (optional) and export addresses for deployment scripts.

3. Run the test suite:

   ```bash
   forge test
   ```

4. Format the codebase:

   ```bash
   forge fmt
   ```

## Contracts

- `FlashLoaner.sol` – Implements the `uniswapV2Call` callback, enforces the expected pair, swaps the
  borrowed asset via a configurable router, and forwards any surplus back to the initiator.
- `UniswapV2Library.sol` – Pure/view helpers for token sorting, deterministic pair derivation, and
  swap math.

Custom errors and structured events have been added to make debugging and integration easier.

## Scripts

Foundry scripts live under `script/`:

- `DeployFlashLoaner.s.sol` deploys the callback contract using `UNISWAP_V2_FACTORY` and
  `UNISWAP_V2_ROUTER` environment variables.
- `SimulateFlashSwap.s.sol` stands up mocked pairs/tokens to trace a complete flash swap flow with
  console logs.
- `QuoteRepayment.s.sol` queries live pair reserves and reports how much of the opposite token is
  needed to repay a flash swap for a given borrowed amount.

Run a script in dry-run mode:

```bash
forge script script/SimulateFlashSwap.s.sol
```

Or broadcast to a configured RPC:

```bash
forge script script/DeployFlashLoaner.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Tests

`test/FlashLoaner.t.sol` exercises the primary behaviors and includes fuzz cases that sweep token
directions, reserve balances, borrow sizes, and profit/shortfall outputs:

- Successful repayment with profit distribution, verified with emitted event data.
- Guard rails for invalid borrow inputs.
- Reverts for unauthorized pairs and underperforming swaps across token directions.

The tests rely on purpose-built mocks that let you seed reserves, override swap outputs, and verify
balances in the simulated pair.

## Tooling

Foundry is the sole toolchain for building, testing, and scripting. No Hardhat dependency is
required.
