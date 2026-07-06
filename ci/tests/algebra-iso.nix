# algebra-iso (law P8): cartesian, tensor and strong are commutative (and associative) up to the
# coordinate isomorphism — addressing is factor-order-free because coordinates are attrsets keyed by
# dimension. Only enumeration order (cells) and the internal codec change under factor reordering.
# Lexicographic is associative but NOT commutative.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) idFactor;
  gp = genProduct;

  fx' = idFactor "x" fx.gA;
  fy' = idFactor "y" fx.gB;

  # Edge relation expressed in COORDINATES (invariant under the codec): a sorted list of JSON-encoded
  # { u; v } coordinate pairs.
  coordEdgeSet =
    p:
    lib.sort lib.lessThan (
      lib.concatMap (
        u: map (t: builtins.toJSON { inherit u; v = gp.coordsOf p t; }) (p.edges (p.product.cellOf u))
      ) (gp.cells p)
    );
  coordSet = p: lib.sort lib.lessThan (map builtins.toJSON (gp.cells p));

  commutes = kind: coordEdgeSet (gp.productN kind [ fx' fy' ]) == coordEdgeSet (gp.productN kind [ fy' fx' ]);

  lexXY = gp.productN "lexicographic" [ fx' fy' ];
  lexYX = gp.productN "lexicographic" [ fy' fx' ];
in
{
  flake.tests.algebra-iso = {
    test-cartesian-commutative = {
      expr = commutes "cartesian";
      expected = true;
    };
    test-tensor-commutative = {
      expr = commutes "tensor";
      expected = true;
    };
    test-strong-commutative = {
      expr = commutes "strong";
      expected = true;
    };
    # lexicographic edge set is order-sensitive.
    test-lex-not-commutative = {
      expr = coordEdgeSet lexXY == coordEdgeSet lexYX;
      expected = false;
    };
    # the CELL SET is invariant under reordering (same coords) …
    test-cell-set-invariant = {
      expr = coordSet (gp.productN "cartesian" [ fx' fy' ]) == coordSet (gp.productN "cartesian" [ fy' fx' ]);
      expected = true;
    };
    # … but the enumeration order (and thus the codec) changes.
    test-enumeration-order-changes = {
      expr = (gp.productN "cartesian" [ fx' fy' ]).nodes == (gp.productN "cartesian" [ fy' fx' ]).nodes;
      expected = false;
    };
  };
}
