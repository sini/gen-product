# gen-product — agent capability sheet

## Scope

Graph products as first-class operations over accessor-graphs: builds the four standard products
(Cartesian / tensor / strong / lexicographic) from named factor specs and answers structural questions
about the resulting lattice — cells, slices, fibers, projections, restriction, quotient, containment
chains — lazy in and lazy out.

## Not this library's job

Quoted text is the owner's own `flake.nix` `description` field, verbatim.

| Responsibility | Owner |
|---|---|
| Building the factor graphs; traversal, condensation, and query combinators over the product | `gen-graph` — "gen-graph: accessor-based graph query combinators". gen-product emits the accessor record and imports no gen library but gen-prelude (see the absence command below) |
| Minting identity (`id_hash`), kinds, registries | `gen-schema` — "gen-schema: typed record registry with extension points for the pure-gen module system". gen-product only *reads* `id_hash`, as the default factor `key` (`lib/factor.nix:31`) and the default quotient `key` (`lib/quotient.nix:30`) |
| Selector predicates over cells (`coord`, `inSlice`) and matching them | `gen-select` — "gen-select: selector algebra for attributed graph positions" |
| Scope-graph construction and attribute evaluation | `gen-scope` — "gen-scope: demand-driven attribute grammar evaluator over algebraic scope graphs" |
| Consuming a containment chain as a precedence layer list | `gen-settings` — "gen-settings — stratified settings resolution as a pure layered fold, with refs-as-data, structured provenance, and the graduated injection construct" |
| Choosing a winner among matched rules | `gen-dispatch` — "gen-dispatch: relational rule dispatch over ordered groups (the dispatch STEP)" |
| Class partition / contract / apply / gate machinery — gen-product supplies only the quotient | `gen-class` — "gen-class — pure-Nix class-share mechanism (partition / contract / apply / gate) for the pure-gen module system" |
| Type checking | `gen-types` — "gen-types: pure, nixpkgs-lib-free structural type checker for the gen ecosystem" |
| General utilities (gen-product's only dependency) | `gen-prelude` — "gen-prelude: vendored, nixpkgs-lib-free pure utilities for the gen ecosystem"; `gen/lib/mkGenLibs.nix:24-26` records the deps as `product: prelude` |
| Emitting membership records from policy | den-hoag, per `lib/membership.nix:4-5` ("emitting membership from policies is den-hoag wiring, never this library's concern"). No gen-* `description` claims it — UNKNOWN whether a gen library owns any part |
| User-facing rendering of a cell (`"sini@axon-01"`) | den-hoag, per `lib/show.nix:3-4`; `show.*` renders only enough to name the offending dimension and value in a throw |
| Prime factorization, cancellation, recognition (Sabidussi–Vizing) | No owner — explicit non-goal (`README.md:178-179`, `lib/default.nix:11`) |

No sibling gen library is named on a non-comment line of `lib/` — the only `import`s there are the
eight sibling files of `lib/` itself:

```sh
git grep -nE '^[[:space:]]*[^#[:space:]].*(gen-graph|gen-schema|gen-select|gen-scope|gen-dispatch|nixpkgs)' -- lib/   # no match
git grep -cE '^[[:space:]]*[^#[:space:]].*gen-product' -- lib/                                                       # control: 5 files
```

## Exports

Entry: `inputs.gen-product.lib` (flake). `import ./lib` is a **function** of `{ prelude }` — required,
no default (`builtins.functionArgs` ⇒ `{"prelude":false}`). Root `default.nix` is a function whose
arguments are all defaulted: `import ./gen-product { }` self-fetches the flake-locked gen-prelude and
yields the same 18 attributes as `.lib`.

**Constructors** — `lib/product.nix`

| Export | Signature |
|---|---|
| `productN` | `kind -> [factorSpec] -> <pgraph>` (`kind` ∈ `cartesian` \| `tensor` \| `strong` \| `lexicographic`; any other throws) |
| `cartesian` / `tensor` / `strong` / `lexicographic` | `f1 -> f2 -> <pgraph>` — binary sugar for `productN` |

**Addressing** — `lib/default.nix`, over `lib/view.nix`

| Export | Signature |
|---|---|
| `cell` | `<pgraph> -> coords -> cellId` (validating: unknown-dim / missing-dim / not-a-node / not-a-member) |
| `coordsOf` | `<pgraph> -> cellId -> coords` |
| `cells` | `<pgraph> -> [coords]` — lattice enumeration, pinned row-major |

**Sub-structures** — `lib/default.nix`, over `lib/view.nix`

| Export | Signature |
|---|---|
| `slice` | `<pgraph> -> partialCoords -> <pgraph>` (fixes a subset of the free dims; base accumulates) |
| `fiber` | `<pgraph> -> dim -> entry -> <pgraph>` (sugar: `slice pg { ${dim} = entry; }`) |
| `projectTo` | `<pgraph> -> dim -> factorGraph // { projection = { dim; ofCell; ofCoords; }; }` |
| `restrict` | `<pgraph> -> membership -> <pgraph>`; `restrict ∘ restrict` conjoins |

**Quotient** — `lib/quotient.nix`

| Export | Signature |
|---|---|
| `quotient` | `graph -> { classOf, key ? (t: t.id_hash), classData ? (t: members: { class = t; inherit members; }), keepSelfLoops ? true } -> graph` — any accessor-graph, not only a product |

**Specificity lattice** — `lib/chain.nix`

| Export | Signature |
|---|---|
| `containmentChain` | `<pgraph> -> coords -> linearization -> [ { fixed; free; slice; rank; } ]` (`2^\|D\|` entries) |
| `linearizeByDimOrder` | `[dim] -> linearization` — count-major |
| `linearizations.byRank` | `{ <dim> = int; … } -> linearization` — top-rank interleave |
| `latticeGraph` | `[dim] -> { nodes; edges = [ { kind; from; to; } ]; }` — the covering relation of `2^D` |

`containmentChain` also accepts a raw comparator `(a: b: bool)` in the `linearization` position,
validated against all comparable subset pairs at `|D| ≤ 8` (`lib/chain.nix:180-192`) — read, not
exercised in this run. The `relations` join (membership enumeration strategy 2, `lib/membership.nix:148-172`)
is likewise read, not exercised; the traps below cover only the `cells` and `predicate` clauses.

**Display, error messages only** — `lib/show.nix`

| Export | Signature |
|---|---|
| `show.cell` | `<pgraph> -> coords -> string` |
| `show.subset` | `[dim] -> string` |

**Factor spec** (consumed, not exported) — `{ dim; graph; key ? (entry: entry.id_hash); entryOf ? graph.nodeData; }`.
A bare accessor-graph is also accepted; it gets the identity codec and a positional `dim` (`lib/factor.nix:24-40`).

**Membership record** (consumed) — `{ cells ? null; relations ? [ ]; predicate ? (_: true); }`; `cells`
holds full **coords**, `relations` are `{ dims; pairs; }` conjoined by natural join (`lib/membership.nix:41-67`).

**`<pgraph>`** (produced) — the accessor record `edges` / `parent` / `nodes` / `nodeData`, plus
`product = { kind; dims; factors; cellOf; coordsOf; base; restriction; }`, plus nine `__`-prefixed
internals (`__def __base __restriction __enumeration __cell __cells __freeDims __showCoords __renderEntry`).

### Contract seam consumed by gen-select

gen-select's `adapters.product.mkContext` is a structural translator with **no gen-product import**
(stated at gen-select `lib/adapters/product.nix:1-8`); from this side the consumed contract is two
outputs plus the coordinate currency.

| gen-select parameter | gen-product output | Evidence |
|---|---|---|
| `cellIds` | `<pgraph>.nodes : [ cellId ]` | `lib/view.nix:204`; `pg.nodes` ⇒ `["[\"H_a\",\"U_s\"]","[\"H_a\",\"U_v\"]",…]` |
| `coordsFor` | `<pgraph>.product.coordsOf : cellId -> { <dim> = entry; }` | `lib/view.nix:245`, codec `lib/view.nix:112-122`; top-level `coordsOf pg cid` is the same function (`lib/default.nix`) |
| `parent` (default `_: null`) | `<pgraph>.parent`, constantly `null` | `lib/view.nix:171`; `pg.parent cid` ⇒ `null` |
| `dataFor` (default `_: { }`) | nothing — gen-product's `nodeData` *is* `coordsOf`, it carries no extra cell data | `lib/view.nix:169` |
| `coord dim entry` requires `entry ? id_hash` (gen-select `lib/adapters/product.nix:16`) | satisfied on the registry path, where `key` defaults to `entry: entry.id_hash` | `lib/factor.nix:31`; `(gp.coordsOf pg cid).host.id_hash` ⇒ `"H_a"` |

**Cells carry no identity of their own** — gen-select hardcoding `__identity = null` matches what this
side emits. `pg.nodeData cid` ⇒ `attrNames` `["host","user"]`, `? __identity` ⇒ `false`, `? __coords` ⇒
`false`; `git grep -n '__identity\|__coords' -- lib/` returns nothing (control, same instrument,
`__def`: 3 files). Identity sits one level down, on the coordinate entries: `(pg.nodeData cid).host`
⇒ `attrNames` `["class","id_hash","name"]`. On the identity-codec path (a bare accessor-graph factor)
coordinates are raw node id **strings** with no `id_hash` at all.

## Entry points by task

| Task | Reach for |
|---|---|
| Build a product over ≥ 2 named dimensions | `productN kind [ f1 f2 … ]` |
| Build the textbook binary product | `cartesian` / `tensor` / `strong` / `lexicographic` |
| Address one cell from coordinates | `cell pg { <dim> = <entry>; … }` |
| Recover coordinates from a cellId | `coordsOf pg cellId` |
| Enumerate the lattice | `cells pg` (coords) or `pg.nodes` (cellIds) |
| Ask a gen-graph query about a product | pass `pg` itself — it is an accessor record |
| Fix some dimensions, keep the rest | `slice pg partialCoords`; `fiber pg dim entry` for exactly one |
| Get one factor back, with its projection | `projectTo pg dim` |
| Model a sparse real fleet | `restrict pg { cells \| relations \| predicate }` |
| Collapse nodes by a class token | `quotient graph { classOf = …; }` (any accessor-graph) |
| Enumerate the specificity ladder of a cell | `containmentChain pg coords (linearizeByDimOrder dims)` |
| Interleave by rank instead of by count | `containmentChain pg coords (linearizations.byRank ranks)` |
| Traverse the specificity lattice as a graph | `latticeGraph dims` (labeled edge list, not an accessor-graph) |
| Name a dimension/value inside your own throw | `show.cell` / `show.subset` |

## Measured traps

Each row verified in this run at rev `c3b8f14` by evaluating against the flake's `.lib` (`gp`).
Shared fixtures: `hosts = { H_a; H_b; H_c; }` and `users = { U_s; U_v; }` are gen-schema-shaped entries
(`id_hash`, `name`); `hostF` / `userF` are registry factor specs (`key = e: e.id_hash`,
`entryOf = id: entries.${id}`) with one host edge `H_a → H_b`; `pg = gp.productN "cartesian" [ hostF userF ]`;
`cid = gp.cell pg { host = hosts.H_a; user = users.U_s; }`; `sl = gp.slice pg { host = hosts.H_a; }`;
`fA` / `fB` are identity-codec factors over bare two-node accessor-graphs; `T e = (builtins.tryEval e).success`.

| Trap | Evidence |
|---|---|
| A restriction's `cells` field holds **coords**, not cellIds — handing it a cellId aborts evaluation, and `tryEval` does **not** catch it | `lib/membership.nix:63`; `gp.restrict pg { cells = [ cid ]; }` ⇒ `error: expected a set but found a string: "[\"H_a\",\"U_s\"]"`, escaping `tryEval`. Positive control, same run: `cells = [ { host = hosts.H_a; user = users.U_s; } { host = hosts.H_c; user = users.U_v; } ]` ⇒ 2 nodes. Test: `test-clause1-cells` (`ci/tests/restrict-membership.nix`) |
| not-a-node detection fires only on a **catchable** failure. The naive registry `entryOf = id: entries.${id}` aborts with a missing-attribute error instead of a `not-a-node` throw — including the repo's own fixture, whose comment calls that access a throw | `lib/view.nix:64-81` (`tryEval`-based); fixture `ci/tests/_fixtures/graphs.nix:38-40`. Unknown coordinate ⇒ `error: attribute 'ghost' missing`, uncaught. Positive control, same harness and run: an `entryOf` failing via explicit `throw` ⇒ `tryEval` caught it (`success = false`). Tests: `test-not-a-node-throwing-entryof`, `test-not-a-node-roundtrip-mismatch` (`ci/tests/identity-errors.nix`) — both use an explicit `throw` |
| A string coordinate aborts on the `key` projection rather than raising `not-a-node` | `lib/factor.nix:31`; `gp.cell pg { host = "axon-01"; user = users.U_s; }` ⇒ `error: expected a set but found a string: "axon-01"`, uncaught by `tryEval` |
| On the identity codec (bare accessor-graph factor) not-a-node detection is **vacuous** — a non-node passes `cell` | `lib/view.nix:60-63`, `lib/factor.nix:13-16`; `gp.cell pgBare { "0" = "NOT-A-NODE"; "1" = "b0"; }` ⇒ succeeds. Test: `test-identity-codec-vacuous` (`ci/tests/identity-errors.nix`) |
| Bare accessor-graph factors get **positional** dimension names | `lib/factor.nix:36`; `pgBare.product.dims` ⇒ `["0","1"]`, and `gp.cell pgBare { "0" = "a0"; "1" = "b0"; }` ⇒ `"[\"a0\",\"b0\"]"` |
| A slice speaks **free** coordinates only, and its cellIds live in a different id space from the parent's | `lib/view.nix:111,271-293`; `sl.product.dims` ⇒ `["user"]`, `sl.nodes` ⇒ `["[\"U_s\"]","[\"U_v\"]"]` against `pg.nodes` ⇒ `["[\"H_a\",\"U_s\"]",…]`. Naming the fixed dim throws in all three places: `gp.cell sl {host;user;}`, `gp.slice sl {host;}`, `gp.projectTo sl "host"` ⇒ all threw. Tests: `test-slice-fixed-dim-errors`, `test-slice-free-dims` (`ci/tests/cell-roundtrip.nix`) |
| A restriction `predicate` always receives **full** coordinates, including dims the slice has fixed | `lib/view.nix:165,229`; on `sl` (host fixed) `predicate = c: c ? host && c ? user` ⇒ 2 nodes, `predicate = c: !(c ? host)` ⇒ 0 nodes |
| `productN kind [ ]` is K1 (one cell, no edges) for **every** kind, but K1 is a unit only for cartesian / strong / lexicographic — a tensor product against it is edgeless | `lib/product.nix:6-9`, `lib/adjacency.nix:56`; `(gp.productN "tensor" [ ]).nodes` ⇒ `["[]"]`; same run, `(gp.productN "cartesian" [ fA k1 ]).edges <a0-cell>` ⇒ one edge vs `(gp.productN "tensor" [ fA k1 ]).edges <a0-cell>` ⇒ `[ ]`. Tests: `test-k1-one-cell`, `test-cartesian-k1-unit-edge`, `test-tensor-k1-edgeless` (`ci/tests/unit-degenerate.nix`) |
| A unary product is isomorphic to its factor but **not equal** to it — cellIds are JSON-wrapped | `lib/view.nix:111`; `unary.nodes` ⇒ `["[\"a0\"]","[\"a1\"]"]` against `gA.nodes` ⇒ `["a0","a1"]`; `unary.edges` ⇒ `["[\"a1\"]"]`. Test: `test-unary-iso-to-factor` (`ci/tests/unit-degenerate.nix`) |
| `latticeGraph` is **not** an accessor-graph: its `edges` is a list of labeled records and it has no `nodeData`/`parent`. Every other returned graph exposes `edges` as a function | `lib/chain.nix:229-246`; `builtins.isList (gp.latticeGraph [ "host" "user" ]).edges` ⇒ `true`, `? nodeData` ⇒ `false`; edges ⇒ `[{from="{}";kind="host";to="{host}";} …]`. Tests: `test-ab-edges`, `test-empty` (`ci/tests/lattice-graph.nix`) |
| `linearizeByDimOrder` is top-level; `byRank` exists **only** under `linearizations` | `lib/chain.nix:89-91`; `gp ? linearizeByDimOrder` ⇒ `true`, `gp ? byRank` ⇒ `false`, `gp.linearizations ? byRank` ⇒ `true` |
| A linearization must name every free dim — an omission throws at chain construction, it does not fall back | `lib/chain.nix:94-106`; `gp.containmentChain pg coords (gp.linearizeByDimOrder [ "host" ])` ⇒ threw. Tests: `test-missing-dim-order-errors`, `test-missing-rank-errors` (`ci/tests/containment-chain.nix`) |
| Pointwise operations survive a factor whose `nodes` throws; the en-masse ones do not | `lib/view.nix:60-63,183-204`; against a factor with `nodes = throw "FORCED-NODES"`, `gp.cell` ⇒ `true` and `pg.edges` ⇒ `true`, while `pg.nodes` ⇒ threw and `gp.cells pg` ⇒ threw. Tests: `test-cell-succeeds`, `test-cells-forces-nodes`, `test-nodes-forces` (`ci/tests/laziness.nix`) |
| Lexicographic `edges` at a non-final dimension forces the **trailing** factor's node list | `lib/adjacency.nix:79-88`; same throwing factor in trailing position: lexicographic `.edges` ⇒ threw, cartesian `.edges` ⇒ `true`. Tests: `test-lex-nonfinal-forces-trailing`, `test-lex-trailing-throw-safe` (`ci/tests/laziness.nix`) |
| `quotient` forces the input's node enumeration at **every** accessor, not only `nodes` | `lib/quotient.nix:40-58`; on a graph with `nodes = throw`, `.nodes` ⇒ threw **and** `.edges "a0"` ⇒ threw, while `gp.productN` over the same throwing factor constructs fine (`.product.dims` ⇒ `true`). Test: `test-quotient-forces-input-nodes` (`ci/tests/laziness.nix`) |
| A predicate-only restriction keeps adjacency pointwise but enumerates the **full** product (strategy 3) | `lib/membership.nix:182-186`; under a throwing-`nodes` factor `.edges cid` ⇒ `true` while `.nodes` ⇒ threw. Test: `test-predicate-adjacency-no-enumerate` (`ci/tests/restrict-membership.nix`) |
| Quotient node ids are class **keys** (strings from `key`), and intra-class edges become self-loops by default | `lib/quotient.nix:68-80`; `q.nodes` ⇒ `["C_cortex","C_blade"]`, `q.nodeData "C_cortex"` ⇒ `attrNames ["class","members"]` with `members = ["H_a","H_b"]`, `q.edges "C_cortex"` ⇒ `["C_cortex"]`; with `keepSelfLoops = false` ⇒ `[ ]`. Tests: `test-edges-with-loops`, `test-edges-no-loops` (`ci/tests/quotient.nix`) |
| `cells` and `nodes` enumerate the same set at different types — coords attrsets against cellId strings | `lib/default.nix` (`cells = pg: pg.__cells`), `lib/view.nix:204`; `gp.cells pg` ⇒ 6 entries each `attrNames ["host","user"]`, `pg.nodes` ⇒ 6 JSON strings |
| Enumeration is pinned row-major in declared factor order, last dimension fastest | `lib/membership.nix:86-95`; `gp.cells pg` ⇒ `H_a/U_s, H_a/U_v, H_b/U_s, H_b/U_v, H_c/U_s, H_c/U_v` (by `id_hash`). Test: `test-cells-row-major` (`ci/tests/enumeration-order.nix`) |
| `parent` is constantly `null` on products and quotients alike — the lattice is flat | `lib/view.nix:171`, `lib/quotient.nix:81`; `pg.parent cid` ⇒ `null`, `q.parent "C_cortex"` ⇒ `null` |
| cellIds are opaque `builtins.toJSON` of the ordered factor keys | `lib/view.nix:111`; `cid` ⇒ `"[\"H_a\",\"U_s\"]"`. Test: `test-codec-opacity` (`ci/tests/cell-roundtrip.nix`) |
| The view builder and membership oracle are not on the public surface | `gp ? mkView`, `gp ? isMember`, `gp ? enumerationOf`, `gp ? targetsFor` ⇒ all `false` |

## Theory

Claimed in `README.md:173-187` under a single **Theoretical Foundations** heading (no
Implements/Informed-by split), restated in per-file `THEORY` comments.

- **Hammack, Imrich & Klavžar, *Handbook of Product Graphs* (2nd ed., CRC Press, 2011), Part I** — the
  four standard products, applied coordinatewise to *directed* adjacency (`lib/adjacency.nix:4-18`);
  projections/layers and the weak-vs-strict homomorphism distinctions (`ci/tests/projection-hom.nix`);
  the associativity/commutativity/unit facts, including the direct product's *looped* unit, which is
  why K1 is not claimed as the tensor unit (`lib/product.nix:6-9`).
- **Kahn, G. 1974, *The Semantics of a Simple Language for Parallel Programming*** — demand-driven
  accessors, inherited via gen-graph's accessor convention; every accessor forces only what a traversal
  visits (`lib/view.nix:14-17`). Documented exceptions: `cells`/`nodes`, the lexicographic trailing
  fan-out, and `quotient`.
- **Mokhov, A. 2017, *Algebraic Graphs with Class* (§4)** — `quotient` generalizes the condensation
  quotient; the quotient map is a strict graph homomorphism, loops allowed (`lib/quotient.nix:9-12`).
- **Davey, B. A. & Priestley, H. A., *Introduction to Lattices and Order* (2nd ed., CUP, 2002),
  §1.2/§2.5** — the boolean lattice `2^D` and its covering relation; `latticeGraph` exposes the cover
  `S ⋖ S∪{d}` as dim-labeled adjacency (`lib/chain.nix:220-228`).
- **Neron/Palmer-style identity is *not* claimed.** The identity law is a boundary convention:
  public coordinates are gen-schema entries and no public function takes a `"kind:name"` string
  (`lib/factor.nix:4-10`).

**Explicitly not realized** (`README.md:178-179`, `lib/default.nix:11`): prime factorization,
cancellation, and recognition theory — "we build products; we never decompose."

**Checked invariant**: the library is nixpkgs-lib-free and depends on gen-prelude alone, enforced by
`ci/tests/purity.nix` over `lib/**.nix` + root `flake.nix` + `default.nix` against the token list at
`ci/tests/purity.nix:46-56` (`ci/` itself is out of scope — its harness uses `nixpkgs.lib`, and
gen-graph enters there as a test-only dev input, `ci/flake.nix:5-8`).

## Drift check

```sh
nix eval --json .#lib --apply 'l: { top = builtins.attrNames l; show = builtins.attrNames l.show; linearizations = builtins.attrNames l.linearizations; }'
```

Current output (verbatim):

```json
{"linearizations":["byRank"],"show":["cell","subset"],"top":["cartesian","cell","cells","containmentChain","coordsOf","fiber","latticeGraph","lexicographic","linearizations","linearizeByDimOrder","productN","projectTo","quotient","restrict","show","slice","strong","tensor"]}
```

**Checks.** Test-runner invocation (from the repo root; CI runs the same command with
`working-directory: ci`, `.github/workflows/ci.yml:13,18`):

```sh
nix flake check ./ci
```
