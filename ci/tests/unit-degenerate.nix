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
      }) (gp.cells p)
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
  unary = gp.productN "cartesian" [ gy ];
in
{
  flake.tests.unit-degenerate = {
    # 0-ary = K1: exactly one cell, no edges, for all kinds.
    test-k1-one-cell = {
      expr = map (kind: lib.length (gp.cells (k1 kind))) [
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
      expr = lib.sort lib.lessThan (unary.edges (gp.cell unary { y = "b0"; }));
      expected = [ (gp.cell unary { y = "b1"; }) ];
    };
    # K1 is a unit for cartesian: G □ K1 ≅ G. Same cell count, and each cell's single out-edge advances
    # only the G dimension (the unit dim stays fixed) — the coordinate-iso witness.
    test-cartesian-k1-unit-cells = {
      expr = lib.length (gp.cells cartUnit);
      expected = lib.length (gp.cells unary);
    };
    test-cartesian-k1-unit-edge = {
      expr = map (t: gp.coordsOf cartUnit t) (
        cartUnit.edges (
          gp.cell cartUnit {
            y = "b0";
            unit = "*";
          }
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
        lib.all (c: t.edges (t.product.cellOf c) == [ ]) (gp.cells t);
      expected = true;
    };
  };
}
