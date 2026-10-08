# gen-product — public API (`genProduct`). Graph products as first-class operations over
# accessor-graphs, lazy in and lazy out. A product is an accessor-graph; every gen-graph query works
# on it unchanged. Class B: depends on gen-prelude only, nixpkgs-lib-free.
#
# THEORY. Hammack, Imrich & Klavžar, *Handbook of Product Graphs* (2nd ed., 2011) — the four standard
# products, projections/layers, (weak) homomorphism distinctions, associativity/commutativity/unit
# facts. Kahn 1974 — demand-driven accessors (laziness). Mokhov 2017 — the quotient map. We build
# products; we never decompose (no prime factorization / cancellation / recognition — explicit
# non-goals).
{ prelude }:
let
  factor = import ./factor.nix { inherit prelude; };
  adjacency = import ./adjacency.nix { inherit prelude; };
  membership = import ./membership.nix { inherit prelude; };
  view = import ./view.nix {
    inherit
      prelude
      adjacency
      membership
      show
      ;
  };
  product = import ./product.nix { inherit prelude factor view; };
  quotient = import ./quotient.nix { inherit prelude; };
  chain = import ./chain.nix {
    inherit
      prelude
      view
      factor
      show
      ;
  };
  show = import ./show.nix { inherit prelude; };

  inherit (view) mkView sliceView enumerationOf;
  inherit (membership) normalizeMembership conjoin;
  inherit (prelude)
    elem
    filter
    attrNames
    head
    concatStringsSep
    ;

  # ── addressing (public wrappers; take/return entries, cellIds are opaque internal keys) ──
  # The product is each door's subject, so it comes last (P2, R7): `nodeAt coords pg`,
  # `coordsOf cellId pg`, `slice partialCoords pg`, `fiber dim entry pg`, `projectTo dim pg`,
  # `restrict membership pg`.
  # A product's cell is its node (TERMINOLOGY.md: "the id gen-graph queries take"), so the
  # addressing doors take the node's word (grammar R8, den-hoag-7gp66 O3). Bare `node`/`nodes` is
  # not free: `pg.nodes` already holds the node-id list (G24).
  nodeAt = view.cell;
  coordsOf = cellId: pg: pg.product.coordsOf cellId;
  nodeCoordinates = pg: pg.__cells;

  # ── THE RETIRED NAMES ──
  # Tombstones rather than silent aliases, as gen-schema's `ref`: each is refused by name and the
  # refusal names its replacement. Published values, not lambdas, so reaching a name refuses as well
  # as applying it; no message interpolates anything.
  cell = throw "gen-product: `cell` is renamed `nodeAt`. A product's cell is the node a graph query takes, so the door takes the node's word (grammar R8); the arguments and the behaviour are unchanged.";
  cells = throw "gen-product: `cells` is renamed `nodeCoordinates`. A product's cell is the node a graph query takes, so the door takes the node's word (grammar R8); the argument and the behaviour are unchanged.";

  slice = partialCoords: pg: sliceView pg partialCoords;
  fiber =
    dim: entry: pg:
    sliceView pg { ${dim} = entry; };

  projectTo =
    dim: pg:
    if !(elem dim pg.product.dims) then
      throw "gen-product: unknown-dim '${dim}' — declared (free) dims: ${concatStringsSep ", " pg.product.dims}"
    else
      let
        f = pg.product.factors.${dim};
      in
      f.graph
      // {
        projection = {
          inherit dim;
          ofCell = cellId: (pg.product.coordsOf cellId).${dim};
          ofCoords = coords: coords.${dim};
        };
      };

  restrict =
    rawMembership: pg:
    let
      inherit (pg.product) def base;
      m = normalizeMembership def rawMembership;
      r = pg.product.restriction;
      combined = if r == null then m else conjoin def r m;
    in
    mkView {
      inherit def base;
      restriction = combined;
      # THE RESTRICTION CHANGED, so the member set changed: this site derives, it does not thread
      # `pg.product.enumeration`. Threading the parent's set here is the one way to make sharing wrong
      # rather than merely fast, which is why the shared value is keyed on (def, restriction) and
      # not on `def` alone.
      enumeration = enumerationOf def combined;
    };
in
product
// quotient
// chain
// {
  inherit (show) show;
}
// {
  inherit
    nodeAt
    cell
    coordsOf
    nodeCoordinates
    cells
    slice
    fiber
    projectTo
    restrict
    ;
}
