# unit-degenerate (law P9): units, honestly. `productN kind [ ]` = K1 (one cell, no edges) — a unit for
# cartesian/strong/lexicographic; NOT for tensor (the tensor unit is the LOOPED one-vertex graph, so
# product with a loop-free K1 is edgeless). `productN kind [ f ]` is isomorphic to `f.graph`.
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

  edgeMap =
    p:
    lib.listToAttrs (
      map (c: {
        name = p.product.cellOf c;
        value = lib.sort lib.lessThan (p.edges (p.product.cellOf c));
      }) (gp.nodeCoordinates p)
    );

  k1 = kind: gp.productN kind [ ];
  gy = idFactor "y" fx.gB;

  # G □ K1 ≅ G : product a 2-factor where one factor is a singleton loop-free K1-like factor.
  k1Factor = idFactor "unit" (
    fx.mkDigraph {
      nodes = [ "*" ];
      edges = [ ];
    }
  );
  cartUnit = gp.productN "cartesian" [
    gy
    k1Factor
  ];
  strongUnit = gp.productN "strong" [
    gy
    k1Factor
  ];
  lexUnit = gp.productN "lexicographic" [
    gy
    k1Factor
  ];
  unary = gp.productN "cartesian" [ gy ];
in
{
  flake.tests.unit-degenerate = {
    # 0-ary = K1: exactly one cell, no edges, for all kinds.
    test-k1-one-cell = {
      expr = map (kind: lib.length (gp.nodeCoordinates (k1 kind))) [
        "cartesian"
        "tensor"
        "strong"
        "lexicographic"
      ];
      expected = [
        1
        1
        1
        1
      ];
    };
    test-k1-edgeless = {
      expr = map (kind: (k1 kind).edges (builtins.head (k1 kind).nodes)) [
        "cartesian"
        "tensor"
        "strong"
        "lexicographic"
      ];
      expected = [
        [ ]
        [ ]
        [ ]
        [ ]
      ];
    };
    # unary product is isomorphic to the factor (edge set matches under the coord codec).
    test-unary-iso-to-factor = {
      expr = lib.sort lib.lessThan (unary.edges (gp.nodeAt { y = "b0"; } unary));
      expected = [ (gp.nodeAt { y = "b1"; } unary) ];
    };
    # K1 is a unit for cartesian: G □ K1 ≅ G. Same cell count, and each cell's single out-edge advances
    # only the G dimension (the unit dim stays fixed) — the coordinate-iso witness.
    test-cartesian-k1-unit-cells = {
      expr = lib.length (gp.nodeCoordinates cartUnit);
      expected = lib.length (gp.nodeCoordinates unary);
    };
    test-cartesian-k1-unit-edge = {
      expr = map (t: gp.coordsOf t cartUnit) (
        cartUnit.edges (
          gp.nodeAt {
            y = "b0";
            unit = "*";
          } cartUnit
        )
      );
      expected = [
        {
          y = "b1";
          unit = "*";
        }
      ];
    };
    # K1 is a unit for strong: G ⊠ K1 ≅ G. Strong = cartesian ∪ tensor, so the cartesian summand
    # carries the G-edges even though the unit coordinate is loop-free; cell count matches and each
    # cell's single out-edge advances only the G dimension (the unit dim stays fixed).
    test-strong-k1-unit-cells = {
      expr = lib.length (gp.nodeCoordinates strongUnit);
      expected = lib.length (gp.nodeCoordinates unary);
    };
    test-strong-k1-unit-edge = {
      expr = map (t: gp.coordsOf t strongUnit) (
        strongUnit.edges (
          gp.nodeAt {
            y = "b0";
            unit = "*";
          } strongUnit
        )
      );
      expected = [
        {
          y = "b1";
          unit = "*";
        }
      ];
    };
    # K1 is a unit for lexicographic: G ∘ K1 ≅ G. With the unit as the trailing factor, its single
    # node is the only "later unconstrained" completion, so each edge advances only the leading G
    # dimension — the coordinate-iso witness.
    test-lex-k1-unit-cells = {
      expr = lib.length (gp.nodeCoordinates lexUnit);
      expected = lib.length (gp.nodeCoordinates unary);
    };
    test-lex-k1-unit-edge = {
      expr = map (t: gp.coordsOf t lexUnit) (
        lexUnit.edges (
          gp.nodeAt {
            y = "b0";
            unit = "*";
          } lexUnit
        )
      );
      expected = [
        {
          y = "b1";
          unit = "*";
        }
      ];
    };
    # tensor with a loop-free K1 is EDGELESS (documented non-unit behaviour pinned).
    test-tensor-k1-edgeless = {
      expr =
        let
          t = gp.productN "tensor" [
            gy
            k1Factor
          ];
        in
        lib.all (c: t.edges (t.product.cellOf c) == [ ]) (gp.nodeCoordinates t);
      expected = true;
    };
  };
}
