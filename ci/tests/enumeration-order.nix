# enumeration-order (law P14): `cells` order is row-major over declared factor order with each factor's
# `nodes` order preserved; product `edges` lists are emitted in the documented per-kind generation
# order, first-seen-deduplicated by cellId; no operation silently reorders or deduplicates
# user-supplied sequences (B5 discipline).
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) idFactor mkDigraph;
  gp = genProduct;

  cart = gp.productN "cartesian" [ (idFactor "x" fx.gA) (idFactor "y" fx.gChain) ];
  cellCoords = c: map (co: { inherit (co) x y; }) (gp.cells c);

  # a factor with a deliberately UNSORTED node order (n2, n0, n1) — enumeration must preserve it, not
  # sort it.
  rev = mkDigraph {
    nodes = [ "n2" "n0" "n1" ];
    edges = [ ];
  };
  revProd = gp.productN "cartesian" [ (idFactor "r" rev) ];
in
{
  flake.tests.enumeration-order = {
    # cells row-major: x slowest, y fastest, each factor's own node order kept.
    test-cells-row-major = {
      expr = cellCoords cart;
      expected = [
        { x = "a0"; y = "c0"; }
        { x = "a0"; y = "c1"; }
        { x = "a0"; y = "c2"; }
        { x = "a1"; y = "c0"; }
        { x = "a1"; y = "c1"; }
        { x = "a1"; y = "c2"; }
      ];
    };
    # per-kind edge generation order (NOT sorted): cartesian emits per moving-dimension in declared
    # order — x's move first, then y's.
    test-cartesian-edge-order = {
      expr = cart.edges (gp.cell cart { x = "a0"; y = "c0"; });
      expected = [
        (gp.cell cart { x = "a1"; y = "c0"; })
        (gp.cell cart { x = "a0"; y = "c1"; })
      ];
    };
    # factor node order preserved (no silent sort).
    test-no-silent-reorder = {
      expr = map (c: c.r) (gp.cells revProd);
      expected = [ "n2" "n0" "n1" ];
    };
    # tensor edge is the single all-advance target.
    test-tensor-edge-order = {
      expr =
        let
          t = gp.productN "tensor" [ (idFactor "x" fx.gA) (idFactor "y" fx.gChain) ];
        in
        t.edges (gp.cell t { x = "a0"; y = "c0"; });
      expected = [ (gp.productN "tensor" [ (idFactor "x" fx.gA) (idFactor "y" fx.gChain) ]).product.cellOf { x = "a1"; y = "c1"; } ];
    };
  };
}
