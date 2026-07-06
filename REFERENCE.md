# gen-product — API Reference

Every function lives under the single `genProduct` attrset returned by `import ./lib { prelude = …; }`
(or the `.lib` flake output). Notation: `<pgraph>` is a product accessor-graph; `<graph>` is any
accessor-graph; `coords` is an attrset of registry entries keyed by dimension name.

- [Data shapes](#data-shapes)
- [Factor specs](#factor-specs)
- [Constructors](#constructors)
- [Cell addressing](#cell-addressing)
- [Enumeration](#enumeration)
- [Slices, fibers, projections](#slices-fibers-projections)
- [Restriction](#restriction)
- [Quotient](#quotient)
- [Containment chain](#containment-chain)
- [Display helpers](#display-helpers)
- [Error taxonomy](#error-taxonomy)
- [Laws](#laws)

## Data shapes

### Product graph (`<pgraph>`)

An accessor-graph extended with a `product` field:

```nix
{
  edges    = cellId: [ cellId ];      # product adjacency
  parent   = _cellId: null;           # products define no intrinsic parent edges
  nodes    = [ cellId ];              # en-masse; forces factor node lists
  nodeData = cellId: coords;          # the coords attrset of entries IS the cell's node data

  product = {
    kind;        # "cartesian" | "tensor" | "strong" | "lexicographic"
    dims;        # [ "host" "user" … ] — declared order (free dims, on a slice)
    factors;     # { host = <factor spec>; … } — free factors, on a slice
    cellOf;      # coords -> cellId   (the raw codec, no validation)
    coordsOf;    # cellId -> coords
    base;        # fixed coords, when this pgraph is a slice ({} otherwise)
    restriction; # membership record, when restricted (null otherwise)
  };
}
```

`cellId` is an opaque internal key (canonical `builtins.toJSON` of the ordered factor node ids); treat
it as opaque and recover coordinates with `coordsOf`.

### Coords

`{ host = den.hosts.axon-01; user = den.users.sini; }` — an attrset of **registry entries** keyed by
dimension name. Partial coords are the same shape over a subset of dimensions.

## Factor specs

```nix
factor = {
  dim;                              # string — dimension name, unique within a product
  graph;                            # accessor-graph for this factor
  key ? (entry: entry.id_hash);     # registry entry -> factor node id (internal key)
  entryOf ? graph.nodeData;         # factor node id -> registry entry (inverse of key)
};
```

- `key` maps public coordinate values (entries) to the factor graph's node ids. The default assumes
  gen-schema instances keyed by `id_hash`. Generic-graph callers override with `key = id: id`.
- **Well-formedness (per factor):** `key (entryOf id) == id` for every node id, and `key` is injective
  on the factor's entries. On non-node ids, `entryOf` must throw or fail the round-trip — that is what
  makes not-a-node detection pointwise (below) without forcing `nodes`.
- A **bare accessor-graph** is accepted where a factor spec is expected: `dim` defaults to its
  positional index as a string, and coordinates *are* the node ids (`key = id: id`, `entryOf = id: id`).
  This identity codec cannot distinguish non-nodes pointwise, so not-a-node detection is **vacuous** on
  this path. den never uses it (identity law).

## Constructors

```nix
productN = kind: factors: <pgraph>;
  # kind ∈ "cartesian" | "tensor" | "strong" | "lexicographic"
  # factors: ORDERED list of factor specs; order is the declared factor order (pins enumeration order
  #   for all kinds; carries adjacency meaning only for lexicographic).

cartesian     = f1: f2: <pgraph>;   # productN "cartesian"     [ f1 f2 ]
tensor        = f1: f2: <pgraph>;   # productN "tensor"        [ f1 f2 ]
strong        = f1: f2: <pgraph>;   # productN "strong"        [ f1 f2 ]
lexicographic = f1: f2: <pgraph>;   # productN "lexicographic" [ f1 f2 ]
```

**Degenerate arities.** `productN kind [ ]` = K1 (one cell, no edges) — a unit for
cartesian/strong/lexicographic, **not** for tensor (the tensor unit is the *looped* one-vertex graph).
`productN kind [ f ]` is isomorphic to `f.graph` under the coordinate codec.

**Nesting.** A `<pgraph>` is an accessor-graph, so it can be a factor of another product; its cells
become opaque single coordinates of the outer product. gen-product does not auto-flatten nested
products.

**Adjacency cost (documented contract).** cartesian `O(Σ outdeg_i)`; tensor `O(Π outdeg_i)`; strong
`O(Π (outdeg_i + 1))`; lexicographic in dimension `k` forces `Π_{i>k} |V_i|` — the lex edges accessor
enumerates the node lists of all trailing factors. This is inherent to the product and is the one
exception to the laziness law.

## Cell addressing

```nix
cell     = pgraph: coords: <cellId>;    # coords: full coordinates, one entry per dimension
coordsOf = pgraph: cellId: coords;      # inverse; entries recovered via each factor's entryOf
```

- `cell` requires **full** coordinates. It validates: unknown dimension, missing dimension,
  coordinate-not-a-node, and (on restricted products) not-a-member — all definition-time errors.
- **Not-a-node detection (pointwise).** A coordinate `entry` in dimension `d` is not-a-node iff
  `key entry` throws, `entryOf (key entry)` throws, or the round-trip `key (entryOf (key entry))`
  mismatches. Never scans `nodes`. Vacuous for identity-codec factors.
- On a **slice**, `cell`/`coordsOf` speak the **free** coordinates only; naming a fixed dimension is an
  `unknown-dim` error. Full-product addresses are reconstructed as `slice.product.base // freeCoords`.

**cellId is the canonical cell identity.** A consumer needing a stable, opaque per-cell key (e.g.
gen-settings assembly keyed per `user@host` cell) uses this cellId; it is derived solely from the
ordered coordinate id_hashes, so equal coordinate identities yield equal cellIds and no other cell
collides with it.

## Enumeration

```nix
cells = pgraph: [ coords ];
```

Lazy lattice enumeration: full-coordinate attrsets in **pinned row-major order** — declared factor
order, last dimension varying fastest, each factor's own `nodes` order preserved. For a restricted
product, `cells` enumerates exactly the members in the restriction's pinned order. `pgraph.nodes` is
`map (cell pgraph) (cells pgraph)` as cellIds. Nix list spines are strict, so `cells`/`nodes` are the
`en-masse` operations (`O(Π |V_i|)` for a full product); every element stays lazy. Sparse fleets should
be `restrict`-ed before enumeration.

**gen-select adapter (informative).** gen-select's product adapter consumes `pgraph.nodes` as its
`cellIds` list and `pgraph.product.coordsOf` as its `coordsFor` accessor.

## Slices, fibers, projections

```nix
slice = pgraph: partialCoords: <pgraph>;   # fix a subset of dims; product over the REMAINING dims
fiber = pgraph: dim: entry: <pgraph>;      # slice pgraph { ${dim} = entry; } — the projection preimage
projectTo = pgraph: dim: <graph>;          # the factor graph of dim, tagged with projection metadata
```

`slice p pc` is the **induced sub-product** — its `nodes` are the cells of `p` extending `pc`
(re-addressed over free dims), its `edges` are the edges of `p` between those cells, and
`.product.base` records the fixed coordinates so slices compose (`slice (slice p a) b == slice p (a // b)`, dims disjoint). Self-loops on fixed coordinates are honored: a looped fixed
coordinate induces a self-loop at every cell (cartesian) or keeps the slice non-edgeless (tensor).

`projectTo` returns `factor.graph // { projection = { dim; ofCell; ofCoords; }; }` where
`ofCell = cellId -> factor entry` and `ofCoords = coords: coords.${dim}`. On a **restricted** product
it returns the **full** factor graph (the dimension's ambient object), not the member image.

**Projection homomorphism status (per kind):** tensor projections are strict homomorphisms; cartesian
and strong are weak (edge ↦ edge or vertex); for lexicographic only the **leading** projection is a
weak homomorphism.

## Restriction

```nix
restrict = pgraph: membership: <pgraph>;

membership = {
  cells     ? null;   # [ coords ] — explicit member list (full coordinates)
  relations ? [ ];    # [ { dims = [ "host" "user" ]; pairs = [ partialCoords ]; } ]
  predicate ? (coords: true);
};
```

A cell `c` is a member iff all three hold: (1) `cells == null` or `c ∈ cells` (by cellId); (2) for
every relation `r`, the projection of `c` onto `r.dims` occurs in `r.pairs` (natural-join semantics —
relations conjoin, pairs within a relation are alternatives); (3) `predicate (coordsOf c)`.

The restricted graph is the induced sub-product: `nodes` = members, `edges c` = product edges filtered
to members, `.product.restriction` = the membership record. `restrict ∘ restrict` conjoins. `cell` on a
non-member is a definition-time error.

**Enumeration strategy (order of preference):** (1) explicit `cells` → first-seen deduplicated, given
order preserved, filtered by (2)+(3); (2) `relations` jointly cover every dimension → relational join,
never materializes the full product; (3) filter the full-product enumeration (`O(Π |V_i|)`). Membership
checks on the adjacency path use point tests, so `edges` of a predicate-restricted product never
enumerates.

## Quotient

```nix
quotient = graph: {
  classOf,                       # node entry -> class token
  key ? (t: t.id_hash),          # class token -> quotient node id
  classData ? (t: members: { class = t; inherit members; }),
  keepSelfLoops ? true,
}: <graph>;
```

A general accessor-graph operation. `classOf` receives the node's data (its registry entry) and returns
a class token. The quotient graph: `nodes` = distinct class keys in first-seen order of `graph.nodes`;
`edges C` = classOf-image of every edge out of every member of `C`, first-seen deduplicated (intra-class
edges become self-loops, dropped iff `keepSelfLoops == false`); `nodeData C` = `classData token members`.
The quotient map is a strict graph homomorphism. Quotient forces the input's node enumeration.

`class-share = quotient hostsGraph { classOf = h: h.class; }`.

## Containment chain

```nix
containmentChain = pgraph: coords: linearization: [ <sliceRecord> ];

sliceRecord = {
  fixed;   # partial coords (attrset of entries) — the fixed dimensions
  free;    # [ dim ] — remaining dimensions, declared order
  slice;   # <pgraph> — LAZY; slice pgraph fixed, unforced until used
  rank;    # position in the chain, 0 = least specific
};
```

For a cell `c` with dimension set `D`, the slices containing `c` are in bijection with subsets
`S ⊆ D`. `containmentChain` returns all `2^|D|` subsets — `∅` (whole product, least specific) to `D`
(the cell, most specific) — as a **linear extension of inclusion**, incomparable subsets ordered by the
declared linearization. It never forces any slice's structure.

```nix
linearizeByDimOrder = dims: <linearization>;
  # key(S) = ( |S|, sortDescending (map rank S) )   where rank d = index of d in dims
  # count-major: fewer fixed dims first. THE DEN FLEET DEFAULT. With [ "env" "host" "user" ]:
  #   ∅ < {env} < {host} < {user} < {env,host} < {env,user} < {host,user} < {env,host,user}

linearizations.byRank = ranks: <linearization>;
  # key(S) = sortDescending (map (d: ranks.${d}) S), compared lexicographically. Top-rank interleave.
  # With { env = 1; host = 2; user = 3; }:
  #   ∅ < {env} < {host} < {env,host} < {user} < {env,user} < {host,user} < {env,host,user}
```

The two differ on incomparable equal-inclusion pairs (`{env,host}` vs `{user}`). A **raw comparator**
(`a: b: bool`, "a strictly less specific than b") is also accepted, validated against all comparable
subset pairs (skipped above `|D| > 8`). Both linearizations **reject degenerate inputs** (an omitted or
duplicated dimension) rather than silently tie-breaking; table keys / list names for dimensions not in
the product are ignored, so a shared fleet-wide linearization applies to smaller products unchanged.

## Display helpers

```nix
show.cell   = pgraph: coords: string;   # "host=axon-01, user=sini" — entry .name if present, else key
show.subset = dims: string;             # "{host,user}"
```

For **error messages only**. den-hoag owns user-facing rendering (`"sini@axon-01"`).

## Error taxonomy

All definition-time throws; messages name the dimension and render the offending value.

| error | trigger |
|---|---|
| `duplicate-dim` | two factors share a `dim` |
| `unknown-dim` | coords/slice/fiber references an undeclared dim (incl. a fixed dim on a slice) |
| `missing-dim` | `cell` given partial coordinates |
| `not-a-node` | pointwise detection fires (scoped to factors meeting the `entryOf` precondition) |
| `not-a-member` | `cell`/`containmentChain` on a restricted product, coords outside membership |
| `bad-linearization` | comparator orders `S ⊂ S'` backwards |
| `missing-rank` / `duplicate-rank` | `byRank` table lacks a rank for / collides on a product dim |
| `missing-dim-order` / `duplicate-dim-order` | `linearizeByDimOrder` omits / repeats a product dim |
| `unknown-kind` | `productN` kind outside the four |

## Laws

Each law is a named test group under `ci/tests`.

| law | statement |
|---|---|
| P1–P4 | per-kind adjacency (cartesian / tensor / strong / lexicographic) vs a brute-force oracle |
| P5 | projection homomorphism table (tensor strict; cartesian/strong weak; lex leading-only) |
| P6 | addressing round-trip, full / restricted / sliced (free-coords; full reconstruction via base) |
| P7 | slice = induced sub-product (loop-free and looped-fixed-coord cases; slice composition) |
| P8 | cartesian/tensor/strong commutative & associative up to coordinate iso; lex non-commutative |
| P9 | units honestly: K1 for cartesian/strong/lex; NOT for tensor |
| P10 | laziness: green under `nodes = throw` for the documented surface; documented forcing exceptions |
| P11 | restriction = induced subgraph; predicate adjacency never enumerates; cells order/dedup; join≡filter |
| P12 | quotient soundness + completeness; strict homomorphism; keepSelfLoops; pinned orders |
| P13 | containment chain = linear extension; byRank & linearizeByDimOrder rules; degenerate rejection |
| P14 | pinned enumeration (cells row-major, per-kind edge order, no silent reorder/dedup) |
| P15 | identity & errors: entries in/out; every error fires; not-a-node fixtures incl. vacuous path |
