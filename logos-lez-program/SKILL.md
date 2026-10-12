---
name: logos-lez-program
description: Review or build a Logos Execution Zone (LEZ) zkVM program — a RISC Zero guest binary wired through the SPEL framework (lez_program/instruction macros), its PDA-derived accounts, and its ChainedCall composition with other programs. Use when the Logos project under review/build is a LEZ program (token, AMM, ATA, stablecoin, oracle, or similar), not a Basecamp/QML app — logos-app-review covers the UI half; this is the on-chain/zkVM half.
---

# Reviewing or building a LEZ zkVM program

A LEZ program is not a Basecamp app: no QML, no `.lgx`, no `callModuleAsync`. It's a RISC-V zkVM
guest binary (`riscv32im-risc0-zkvm-elf`) compiled by RISC Zero, wired to the LEZ runtime via the
`spel-framework`'s `#[lez_program]` / `#[instruction]` macros, and driven by pure host-side
functions that take account state and return new account state. This skill is the LEZ-specific half
of a review or a build; `logos-app-review` is the UI/transport half when the same project also ships
a Basecamp front end or wallet client.

## The layered pattern (what to expect in the repo)

Four layers per program, usually under `programs/<name>/`:
1. **`<name>_core`** — shared types: the `Instruction` enum (serde JSON, for off-chain instruction
   passing) and account data structs (Borsh, for on-chain storage). Also PDA seed computation, if
   the program derives addresses.
2. **`<name>` (program crate)** — pure functions: `AccountWithMetadata` in, `Vec<AccountPostState>`
   out (plus `Vec<ChainedCall>` if it composes with other programs). No I/O, no global state — every
   state transition should be independently unit-testable without a zkVM.
3. **`methods/guest`** — the actual guest binary, a *separate* Cargo workspace targeting
   `riscv32im-risc0-zkvm-elf`, wiring the program crate's logic to the runtime via
   `#[lez_program]`/`#[instruction]`.
4. **`methods`** — the host-side crate that embeds the compiled guest ELF (via `risc0_build::embed_methods`
   in its `build.rs`) for tests and deployment.

## Build/test — what actually compiles what

- `RISC0_DEV_MODE=1 cargo test -p <pkg>_program` runs the real program logic with **no ZK proof
  generation** — this is where you verify business logic (swap math, PDA derivation, authorization)
  cheaply. This should be most of a review's test-running.
- A workspace-wide `cargo check`/`clippy` with `RISC0_SKIP_BUILD=1` set (common in a `make clippy`
  target) **does not compile the guest crates at all** — it can pass clean while the actual guest
  binary is broken. If a review needs to confirm the guest side actually builds, look for and run
  the guest-specific lint/build target (e.g. a `make clippy-guest` or `cargo risczero build
  --manifest-path programs/<name>/methods/guest/Cargo.toml`), not just the top-level check.
- **An `Instruction` enum variant and its guest entry must land together.** The `#[lez_program]`
  macro generates an exhaustive match over the program's `Instruction` enum; a new variant with no
  matching `#[instruction]` guest function fails the guest build with `error[E0004]: non-exhaustive
  patterns` — a failure the workspace-level check above won't catch. If a PR adds an instruction
  variant, confirm the guest-side match arm shipped in the same diff, not a follow-up.
- Integration tests that exercise the real zkVM path (not `RISC0_DEV_MODE=1`) take real proving time;
  expect them in a slower `integration_tests/` suite, separate from the per-program unit tests.

## IDL — verify it matches the source, don't just check it exists

A SPEL IDL (JSON) should be generated straight from the guest source
(`cargo run -p idl-gen -- programs/<name>/methods/guest/src/bin/<name>.rs`, or the `spel
generate-idl` CLI). **Check that the committed IDL in `artifacts/` was actually regenerated after
the last source change that touched an instruction's shape** — a stale committed IDL that still
parses is a realistic silent-drift failure mode (the same class of bug `logos-basecamp-module`
documents for Basecamp module contracts going stale against their header). Regenerate it yourself
and diff against what's committed rather than trusting that it was.

## PDA derivation and account authorization — the two places logic bugs hide

- **PDA seeds are a public contract.** If a program derives addresses (pools, vaults, token
  accounts) from seeds, confirm the seed computation is deterministic, documented, and that the
  *same* derivation is used by every caller (a client, a chained-call caller, a test) — a seed
  mismatch between the program and a client is a silent "account not found" or, worse, a different
  account than the one intended.
- **Every account an instruction touches must be explicitly authorized**, not just present. Read
  each instruction's handler for every account it reads or writes and confirm there's a check that
  the signer/authority is who the instruction claims, not merely that the account exists at the
  expected PDA. A PDA being derivable from public seeds means anyone can *name* the account; only an
  authorization check stops anyone from *acting as* it.
- **`ChainedCall` account ordering is load-bearing.** When one program instructs another as part of
  the same atomic operation (e.g. an AMM instructing the token program to execute a transfer), the
  callee reads accounts by position/role from what the caller supplies. Confirm the caller builds
  the chained call's account list in the exact order and role the callee's own instruction handler
  expects — this is the same class of fragility as a Basecamp module's positional-argument limit,
  just enforced by convention instead of a generated contract.

## Math-heavy programs (AMM, stablecoin, anything with a formula)

Specifically check, by reading the code (not just running the happy-path test):
- **Rounding direction** on every division — consistently rounding in the protocol's favor (not the
  user's) is the usual intent; confirm it, don't assume it.
- **First-depositor / first-mint edge cases** (constant-product AMMs: the first liquidity deposit
  sets the initial ratio and is a classic inflation-attack surface).
- **Fee accounting**: that fees taken are actually conserved somewhere (added to a vault, minted to
  a fee account) rather than silently vanishing from the ledger.
- **Oracle/TWAP seeding**: whether a freshly-initialized price account can be manipulated before it
  has enough observations to be meaningful.

## Compute budget

LEZ's per-transaction compute budget may change during testnet — if a program's spec or submission
requirements ask for documented compute-unit (cycle) cost per operation, actually run and record it
rather than estimating; this is cheap to verify (the zkVM's own cycle counter) and is exactly the
kind of claim that's easy to leave stale across a refactor.

## Deployment identity — ImageID is the whole ballgame

- The **ImageID** (the hash of the compiled guest binary) is the program's identity on-chain.
  **Any change to the release build profile, the toolchain, or the source changes the ImageID.**
  After every release build, re-inspect the binary (`spel inspect <binary>.bin`) and update *every*
  value that depends on it: deployed program IDs, client/config files, PDA-derived account addresses
  computed from the program ID, and any other program's hardcoded reference to this one (e.g. an AMM
  config pointing at a token program's ID). Treat a submission or PR that bumps a dependency or
  toolchain without re-checking these as a likely silent break, even if its own tests pass — its own
  tests were built against its own (old or new) ImageID and won't show a mismatch against a
  *different* consumer still pointing at the other one.
- Don't mix a raw/dev-profile ImageID with a release-profile binary when verifying — they're
  different identities even from identical source.

## Where else this applies

Any Logos program on LEZ, not just token/AMM/ATA/stablecoin/oracle: the layered core/program/guest
split, the dev-mode-vs-real-proving test split, the IDL-matches-source check, PDA/authorization
review, and the ImageID-is-identity rule are protocol-level concerns independent of what the program
actually does.

## Sources

The build/test/IDL/deployment mechanics above are the documented conventions of a real LEZ program
workspace (see that workspace's own `CLAUDE.md` for the authoritative, project-specific commands —
this skill generalizes the pattern, not the exact command line, which will vary by repo). The
PDA/authorization/ChainedCall and math-review guidance is general smart-contract-review practice
applied to this architecture, not drawn from a specific documented incident the way the Basecamp
skills' footnoted traps are — treat it as a starting checklist to verify against the actual program
under review, not a list of confirmed historical bugs.
