# LarzGig

Multi-milestone freelance contracts, written entirely in Larzscript, the
money-native language. A client's full budget escrows the moment a
contract is created, split across named milestones. Each milestone
releases to the freelancer on approval — but a disputed milestone isn't
all-or-nothing: an arbiter can **split** its locked amount between both
sides, and a real `require` refuses the split outright if the rounded
halves don't actually add back up to the amount that was locked.

Part of the [Larzscript ecosystem growth plan](https://github.com/larz-scripter/larzscript/blob/main/GROWTH.md)'s
flagship-app track (alongside [`LarzBank`](https://github.com/larz-scripter/larzscript-bank),
[`LarzBounty`](https://github.com/larz-scripter/larzscript-bounty),
[`LarzCrowd`](https://github.com/larz-scripter/larzscript-crowd), and
[`LarzInsure`](https://github.com/larz-scripter/larzscript-insure)).

## Why this needed `require` for something that isn't a tautology

LarzBounty's escrow always goes entirely to one side. LarzCrowd's always
refunds entirely to many sides. A disputed gig milestone is different —
an arbiter might reasonably say "60% to the freelancer, 40% back to the
client" for a job that was *mostly* done right. The two shares are
rounded **independently**, each to the cent:

```larzscript
let freelancer_amt = round(m["amount"] * to_freelancer_pct, 2)
let client_amt = round(m["amount"] * (1.0 - to_freelancer_pct), 2)
require freelancer_amt + client_amt == m["amount"], "dispute split does not reconcile to the milestone amount"
```

That's not a tautology — it genuinely fails sometimes. A $10.01
milestone split 50/50: `round(10.01 * 0.5, 2)` is `$5.01` on **both**
sides (it rounds up past the midpoint), so the two halves sum to
`$10.02` — one cent more than was ever actually locked in escrow. The
`require` catches that for real and refuses the split before either
payment happens, rather than quietly minting a cent from nowhere. The
demo below shows this exact case.

## Quickstart

```bash
larzscript bin/larzgig.lz fund cara 500
larzscript bin/larzgig.lz create cara sam "Landing page" Wireframes 100 Build 300
larzscript bin/larzgig.lz submit <id> 0
larzscript bin/larzgig.lz approve <id> 0
larzscript bin/larzgig.lz dispute <id> 1 "not what we agreed"
larzscript bin/larzgig.lz resolve <id> 1 0.6 "partial credit"
```

State (wallets, contracts, reputation) persists to `board.json` in the
current directory across runs — each command is a fresh process; see
"How it's built" below for how that's made to work with a native
`wallet` value, which isn't something JSON can hold. Override the state
file with `--board=path/to/file.json`.

## Real transcript (`sh examples/demo.sh`, copy-pasted, not invented)

```
--- fund a client (demo-only faucet) ---
cara balance is now $500
--- cara hires sam for a two-milestone contract - the FULL budget escrows now ---
created e2f2178b  "Landing page"  2 milestone(s)
full id: e2f2178b-b51f-4cc8-acfa-0e4500f59a23
cara: $100
id:         e2f2178b-b51f-4cc8-acfa-0e4500f59a23
title:      Landing page
client:     cara
freelancer: sam
status:     active
holding:    $400
milestones:
  [0] Wireframes  $100  [pending]
  [1] Build  $300  [pending]
--- milestone 0: sam submits, cara approves - pays out immediately ---
milestone 0 submitted
milestone 0 approved and paid
sam: $100
--- milestone 1: cara isn't happy with the build - disputes it ---
milestone 1 submitted
milestone 1 marked disputed
--- an arbiter looks at it and splits it 60/40 in sam's favor ---
resolved: freelancer gets $180, client refunded $120
sam: $280
cara: $220
id:         e2f2178b-b51f-4cc8-acfa-0e4500f59a23
title:      Landing page
client:     cara
freelancer: sam
status:     completed
holding:    $0
milestones:
  [0] Wireframes  $100  [approved]
  [1] Build  $300  [resolved]
      resolved: freelancer $180, client $120 - partial credit - scope was ambiguous
sam: 1 contract(s) completed, 1 milestone(s) approved clean, 1 disputed

--- second contract: an odd-cent milestone, disputed, split 50/50 ---
created d9126c71  "Odd amount test"  1 milestone(s)
full id: d9126c71-f74c-4671-a349-ab31c8eb79b9
milestone 0 submitted
milestone 0 marked disputed
--- 10.01 * 0.5 rounds to 5.01 on BOTH sides - that's $10.02, a cent more than was ever locked ---
error: dispute split does not reconcile to the milestone amount - try a rounder percentage (line 168)
--- refused - nobody got paid, the $10.01 is still sitting exactly where it was ---
cara: $209.99
sam2: $0
id:         d9126c71-f74c-4671-a349-ab31c8eb79b9
title:      Odd amount test
client:     cara
freelancer: sam2
status:     active
holding:    $10.01
milestones:
  [0] Design  $10.01  [disputed]
```

## Commands

| Command | What it does |
|---|---|
| `fund <name> <amount>` | Demo-only faucet — credits a balance directly. A real deployment replaces this with an actual funding flow. |
| `create <client> <freelancer> <title> <m1_title> <m1_amount> [<m2_title> <m2_amount> ...]` | Opens a contract. The full sum of every milestone escrows from the client immediately. |
| `submit <id> <milestone_index>` | Marks a pending milestone as submitted (0-based index). |
| `approve <id> <milestone_index>` | Releases that milestone's exact amount to the freelancer from the shared holding wallet. |
| `dispute <id> <milestone_index> <reason>` | Marks a submitted milestone as disputed. |
| `resolve <id> <milestone_index> <to_freelancer_pct> <note>` | Arbiter resolves a disputed milestone, splitting its locked amount by `to_freelancer_pct` (0.6 = 60% to the freelancer, 40% back to the client). Refuses outright if the rounded halves don't reconcile — see above. |
| `list` | Lists every active contract. |
| `show <id>` | Full detail on one contract: every milestone, its status, and its resolution if disputed. `<id>` may be the short 8-character prefix `create`/`list` print. |
| `reputation <name>` | Shows a freelancer's completed-contract count and clean-approval vs. disputed milestone counts. |
| `balance <name>` | Shows the current balance. |

## How it's built

- **`lib/moneyx.lz`** — the bridge between the native `wallet`/Money
  type and a plain float, for persisting balances to JSON. There is no
  `float(money)` builtin; stripping the leading `"$"` off `str(m)` is
  the real, working conversion.
- **`lib/gig.lz`** — contracts, milestones, and the dispute/resolution
  logic described above, plus a reputation tracker that updates the
  moment every milestone in a contract reaches a terminal state
  (approved or resolved). Every escrow move is a real `wallet`
  reconstructed from the persisted float balance, doing its real work
  under `escrow.open`/`release`/`refund`, converted back to a float
  before being written to JSON.
- **`bin/larzgig.lz`** — the CLI. Each invocation loads `board.json`,
  does one thing, saves it back. `_find_by_prefix()` rejects a
  too-short/empty id outright rather than risk matching the wrong
  contract — the same class of bug found and fixed in the sibling
  LarzBounty/LarzCrowd projects, applied here from the start.

## Limitations (read before treating this as more than a toy)

- **`fund` is a faucet, not a payment rail.** There's no real deposit
  flow behind it.
- **No identity/authorization model.** Anyone running the CLI can call
  `approve` or `resolve` — there's no notion of "only the client can
  approve" or "only a designated arbiter can resolve" enforced by the
  tool itself. A real deployment needs an auth layer in front of this.
- **Milestones can't be added after contract creation**, and there's no
  partial-refund/cancellation path for a contract abandoned mid-way.
- **Reputation is a simple running count**, not a weighted or
  time-decayed score — a freelancer who disputed once ten years ago
  looks the same as one who disputed last week.
- **Floating-point, not arbitrary-precision.** Larzscript's only numeric
  type is a double, the same limitation every Larz Stack money package
  documents.
- **Single-process, no concurrent access.** Two `larzgig` invocations
  racing against the same `board.json` can clobber each other — fine
  for a personal CLI tool, not for anything multi-user.
- **`board.json` is not encrypted or access-controlled.** Don't put real
  financial data in it.

## Tests

```bash
sh tests/run_tests.sh
```

Real CLI output, diffed against `tests/*.expected`, `uuid.v4()` ids
normalized like the sibling projects. Covers: a full contract lifecycle
(one milestone approved cleanly, one disputed and resolved with a
reconciling 60/40 split, reputation updating correctly), the
reconciliation `require` genuinely refusing a non-reconciling 50/50
split on an odd-cent amount, and the too-short-id-prefix guard plus a
couple of ordinary status-transition rejections.

## License

MIT
