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
  view = import ./view.nix { inherit prelude adjacency membership; };
  product = import ./product.nix { inherit prelude factor view; };
  quotient = import ./quotient.nix { inherit prelude; };
  chain = import ./chain.nix { inherit prelude view; };
  show = import ./show.nix { inherit prelude; };

  inherit (view) mkView sliceView;
  inherit (membership) normalizeMembership conjoin;
  inherit (prelude)
    elem
    filter
    attrNames
    head
    concatStringsSep
    ;

  # ── addressing (public wrappers; take/return entries, cellIds are opaque internal keys) ──
  cell = pg: coords: pg.__cell coords;
  coordsOf = pg: cellId: pg.product.coordsOf cellId;
  cells = pg: pg.__cells;

  slice = sliceView;
  fiber =
    pg: dim: entry:
    sliceView pg { ${dim} = entry; };

  projectTo =
    pg: dim:
    if !(elem dim pg.product.dims) then
      throw "gen-product: unknown-dim '${dim}' — declared (free) dims: ${concatStringsSep ", " pg.product.dims}"
    else
      let
        f = pg.__def.factorsByDim.${dim};
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
    pg: rawMembership:
    let
      m = normalizeMembership rawMembership;
      r = pg.__restriction;
      combined = if r == null then m else conjoin pg.__def r m;
    in
    mkView {
      def = pg.__def;
      base = pg.__base;
      restriction = combined;
    };
in
product
// quotient
// chain
// show
// {
  inherit
    cell
    coordsOf
    cells
    slice
    fiber
    projectTo
    restrict
    ;
}
