# adjacency-strong (law P3): edge iff every dimension is equal-or-edge and at least one is an edge.
# Same oracle harness, plus the binary corollary strong = cartesian ∪ tensor edge set.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) idFactor implEdgeMap oracleEdgeMap;
  gp = genProduct;

  binFactors = [ (idFactor "x" fx.gB) (idFactor "y" fx.gB) ];
  bin = gp.productN "strong" binFactors;
  cart = gp.productN "cartesian" binFactors;
  tens = gp.productN "tensor" binFactors;

  triFactors = [ (idFactor "x" fx.gB) (idFactor "y" fx.gB) (idFactor "z" fx.gChain) ];
  tri = gp.productN "strong" triFactors;

  loopFactors = [ (idFactor "p" fx.gLoop) (idFactor "q" fx.gB) ];
  loop = gp.productN "strong" loopFactors;

  cells = gp.cells bin;
  # union of cartesian and tensor edge maps, per cell, sorted.
  unionMap = lib.listToAttrs (
    map (
      c:
      let
        cid = bin.product.cellOf c;
      in
      {
        name = cid;
        value = lib.sort lib.lessThan (lib.unique (cart.edges cid ++ tens.edges cid));
      }
    ) cells
  );
in
{
  flake.tests.adjacency-strong = {
    test-binary-matches-oracle = {
      expr = implEdgeMap gp bin cells;
      expected = oracleEdgeMap gp bin "strong" binFactors cells;
    };
    test-ternary-matches-oracle = {
      expr = implEdgeMap gp tri (gp.cells tri);
      expected = oracleEdgeMap gp tri "strong" triFactors (gp.cells tri);
    };
    test-selfloop-matches-oracle = {
      expr = implEdgeMap gp loop (gp.cells loop);
      expected = oracleEdgeMap gp loop "strong" loopFactors (gp.cells loop);
    };
    # Corollary: strong edge set = cartesian ∪ tensor (binary).
    test-strong-is-cartesian-union-tensor = {
      expr = implEdgeMap gp bin cells;
      expected = unionMap;
    };
  };
}
