# adjacency-lex (law P4): edge iff at the first differing dimension (declared order) there is a factor
# edge, all earlier dims equal, later dims unconstrained. Binary matches G ∘ H; order sensitivity is
# part of the law (factor-swap negative test); trailing-dim fan-out shape asserted.
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

  xy = [ (idFactor "x" fx.gA) (idFactor "y" fx.gChain) ];
  lexXY = gp.productN "lexicographic" xy;

  tri = [ (idFactor "x" fx.gA) (idFactor "y" fx.gB) (idFactor "z" fx.gChain) ];
  lexTri = gp.productN "lexicographic" tri;

  # swapped factor order — a DIFFERENT product.
  yx = [ (idFactor "y" fx.gChain) (idFactor "x" fx.gA) ];
  lexYX = gp.productN "lexicographic" yx;
in
{
  flake.tests.adjacency-lex = {
    test-binary-matches-oracle = {
      expr = implEdgeMap gp lexXY (gp.cells lexXY);
      expected = oracleEdgeMap gp lexXY "lexicographic" xy (gp.cells lexXY);
    };
    test-ternary-matches-oracle = {
      expr = implEdgeMap gp lexTri (gp.cells lexTri);
      expected = oracleEdgeMap gp lexTri "lexicographic" tri (gp.cells lexTri);
    };
    # Trailing-dim fan-out: from (a0, c0), the leading dim advances a0 -> a1, so the trailing dim y
    # ranges over ALL of gChain's nodes { c0, c1, c2 } — 3 targets from the leading move alone, plus
    # the trailing move (a0 equal, c0 -> c1). Assert the leading fan-out is present in full.
    test-trailing-fanout = {
      expr = lib.all (yid: lib.elem (gp.cell lexXY { x = "a1"; y = yid; }) (lexXY.edges (gp.cell lexXY { x = "a0"; y = "c0"; }))) [
        "c0"
        "c1"
        "c2"
      ];
      expected = true;
    };
    # Order sensitivity: swapping the two factors changes the edge set (negative test). Compare the
    # out-neighbour COUNT of a corresponding cell — leading gChain fans out gA's 2 nodes differently.
    test-factor-swap-differs = {
      expr =
        (lib.length (lexXY.edges (gp.cell lexXY { x = "a0"; y = "c0"; })))
        == (lib.length (lexYX.edges (gp.cell lexYX { x = "a0"; y = "c0"; })));
      expected = false;
    };
  };
}
