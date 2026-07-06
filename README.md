# gen-product — graph products as first-class operations for Nix

[![CI](https://github.com/sini/gen-product/actions/workflows/ci.yml/badge.svg)](https://github.com/sini/gen-product/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?logo=github)](https://github.com/sponsors/sini)

Pure graph products for Nix. gen-product builds the four standard graph products — **Cartesian**,
**tensor** (direct), **strong**, and **lexicographic** — over *accessor-graphs*, the
[gen-graph](https://github.com/sini/gen-graph) accessor-record convention. Products are **lazy in and
lazy out**: a product *is* an accessor-graph (every gen-graph query works on it unchanged), extended
with product metadata that gen-product's own operations read.

gen-product is **nixpkgs-lib-free** (Class B): it depends only on
[gen-prelude](https://github.com/sini/gen-prelude), the pure utility base. It imports no other gen
library — its entire integration story is the shared accessor record `{ edges, parent, nodes, nodeData }` and the gen-schema instance shape (`id_hash`, `name`) as the default coordinate currency.

## Table of Contents

- [Overview](#overview)
- [Gen Ecosystem](#gen-ecosystem)
- [Quick Start](#quick-start)
- [Design Principles](#design-principles)
- [API Reference](#api-reference)
- [den convergences](#den-convergences)
- [Testing](#testing)
- [Theoretical Foundations](#theoretical-foundations)

## Overview

A **product** takes ordered **factor specs** — named dimensions whose coordinates are registry
entries (the identity law: public inputs carry gen-schema identity, never `"kind:name"` strings) — and
answers structural questions about the product-shaped graph they span:

```nix
genProduct = import (builtins.getFlake "github:sini/gen-product").lib { prelude = …; };

# a factor spec names a dimension and supplies its accessor-graph
hostFactor = { dim = "host"; graph = hostsGraph; };   # key defaults to (e: e.id_hash)
userFactor = { dim = "user"; graph = usersGraph; };

fleet = genProduct.productN "cartesian" [ hostFactor userFactor ];

# a CELL is a full coordinate — the id gen-graph queries take
cellId = genProduct.cell fleet { host = hosts.axon-01; user = users.sini; };
fleet.edges cellId                        # product adjacency (an ordinary accessor)
genProduct.coordsOf fleet cellId          # → { host = <entry>; user = <entry>; }
```

Adjacency per kind — the cell `u = { d_i = u_i }` has an edge to `v = { d_i = v_i }` (writing
`u_i ~ v_i` for a directed factor edge):

| kind | edge rule |
|---|---|
| **cartesian** (`□`) | exactly one dimension has `u_i ~ v_i`; all others equal |
| **tensor** (`×`) | every dimension has `u_i ~ v_i` |
| **strong** (`⊠`) | every dimension is equal-or-edge, at least one is an edge |
| **lexicographic** (`∘`) | at the first differing dimension: `u_i ~ v_i`; earlier equal; later free |

These are the standard product definitions applied coordinatewise to **directed** adjacency; on
symmetric edge relations they degenerate to the textbook objects (K2□K2 = C4, K2×K2 = 2K2,
K2⊠K2 = K4, K2∘K2 = K4).

## Gen Ecosystem

| Library | Role |
|---------|------|
| [gen-prelude](https://github.com/sini/gen-prelude) | Pure nixpkgs-lib-free utility base |
| [gen-graph](https://github.com/sini/gen-graph) | Accessor-based graph query combinators (the accessor-record convention gen-product builds on) |
| [gen-schema](https://github.com/sini/gen-schema) | Typed registries (the `id_hash`/`name` instance shape used as the default coordinate currency) |
| [gen-scope](https://github.com/sini/gen-scope) | HOAG scope-graph evaluator |
| [gen-select](https://github.com/sini/gen-select) | Selector algebra (consumes product cells via the cell adapter) |
| **gen-product** | **This lib** — graph products (Cartesian / tensor / strong / lexicographic; cells, slices, fibers, projections, quotients, restriction, containment chains) |

## Quick Start

### As a flake input

```nix
{
  inputs.gen-product.url = "github:sini/gen-product";
  # gen-product pulls in gen-prelude transitively — no nixpkgs input required.
}
```

Then `gen-product.lib` is the `genProduct` attrset.

### Standalone (non-flake)

```nix
let genProduct = import (fetchTarball "https://github.com/sini/gen-product/archive/main.tar.gz") { };
in genProduct.cartesian hostFactor userFactor
```

## Design Principles

- **A product is an accessor-graph.** `productN`, `slice`, `fiber`, `restrict`, and `quotient` all
  return the accessor record `{ edges, parent, nodes, nodeData }` (plus a `product` metadata field);
  gen-graph queries apply unchanged, and products nest as factors of other products.
- **Lazy in, lazy out.** Adjacency, cell addressing, slices, projections, and containment chains never
  scan a factor's `nodes` list — not-a-node and not-a-member detection is *pointwise* (via a codec
  round-trip), so `cell` and `containmentChain` succeed even under `nodes = throw …`. The `en-masse`
  operations (`cells`, `nodes`) and the lexicographic trailing-dimension fan-out are the documented
  exceptions.
- **Identity at the boundary.** Coordinates are **registry entries** keyed by dimension name; cellIds
  are opaque internal keys (canonical `builtins.toJSON` of the ordered factor node ids). No public
  function takes or returns a `"kind:name"` string.
- **No decomposition.** gen-product *builds* products; it never factors a graph into primes (no
  Sabidussi–Vizing recognition/cancellation). It answers structural questions only — it never
  evaluates content.

## API Reference

The complete surface is documented in [REFERENCE.md](./REFERENCE.md). In brief:

```nix
# constructors
productN       = kind: factors: <pgraph>;       # kind ∈ cartesian | tensor | strong | lexicographic
cartesian | tensor | strong | lexicographic = f1: f2: <pgraph>;

# addressing (coords are attrsets of registry entries)
cell     = pgraph: coords: <cellId>;
coordsOf = pgraph: cellId: coords;
cells    = pgraph: [ coords ];                  # lazy lattice enumeration, pinned row-major

# sub-structures
slice     = pgraph: partialCoords: <pgraph>;    # induced sub-product over remaining dims
fiber     = pgraph: dim: entry: <pgraph>;       # preimage of the projection onto dim
projectTo = pgraph: dim: <graph>;               # factor graph + projection metadata
restrict  = pgraph: membership: <pgraph>;       # sparse sub-product (the real fleet)
quotient  = graph: { classOf, … }: <graph>;     # class-share = quotient by class

# specificity lattice
containmentChain = pgraph: coords: linearization: [ <sliceRecord> ];
linearizeByDimOrder = dims: <linearization>;    # count-major — the den fleet default
linearizations.byRank = ranks: <linearization>; # top-rank interleave

# error-message helpers (not a rendering API)
show.cell   = pgraph: coords: string;
show.subset = dims: string;
```

## den convergences

The generality gen-product buys, documented here and wired in den-hoag:

| den concept | gen-product expression |
|---|---|
| user@host scoped config | a **cell** of `hosts × users` |
| the real fleet | **restrict**(full product, membership relation) — not every user exists on every host |
| class-share | **quotient** of the host graph by class |
| matrix instantiation | **cells** enumeration |
| settings specificity | **containmentChain**, consumed by gen-settings as a layer list |

## Testing

Law-based suites under `ci/`, one named test group per law, plus goldens and a brute-force adjacency
oracle recomputed independently of the library. gen-graph's `mkGraph` is a test-only dev input.

```bash
cd ci && nix-unit --flake .#tests        # run everything
nix-unit --flake .#tests.adjacency-lex   # a single suite
```

The library source (`lib/**.nix`) is verified nixpkgs-lib-free by `ci/tests/purity.nix`.

## Theoretical Foundations

- **Hammack, Imrich & Klavžar — _Handbook of Product Graphs_ (2nd ed., CRC Press, 2011).** The four
  standard products (Part I), the projection/layer vocabulary, the (weak) homomorphism distinctions,
  and the associativity/commutativity/unit facts — including the direct product's *looped* unit, which
  is why gen-product refuses a tensor unit claim for K1. Deliberately **not** realized: prime
  factorization, cancellation, and recognition theory.
- **Kahn, G. 1974 — _The Semantics of a Simple Language for Parallel Programming_** (inherited via
  gen-graph's accessor convention). Demand-driven structure: adjacency accessors force only what a
  traversal visits — the laziness discipline restated for products.
- **Mokhov, A. 2017 — _Algebraic Graphs with Class_.** `quotient` generalizes the condensation
  quotient gen-graph already implements; the quotient map is the standard strict homomorphism.
