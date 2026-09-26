# record-surface (den-hoag-4kh.53.53, R12): the published pgraph carries no undeclared `__` key on any
# constructor — `__cells` is the one, with its contract in AGENTS.md `<pgraph>` — and gen-product's
# own operations read the declared `product` field, so the state a slice or a restriction is built
# from is a stated field (`def`, `enumeration`).
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
  g = nodes: {
    inherit nodes;
    edges = _: [ ];
    parent = _: null;
    nodeData = _: { };
  };
  p = gp.productN "cartesian" [
    (idFactor "a" (g [
      "a1"
      "a2"
    ]))
    (idFactor "b" (g [
      "b1"
      "b2"
    ]))
  ];
  r = gp.restrict p {
    cells = [
      {
        a = "a1";
        b = "b1";
      }
    ];
  };
  published = [
    p
    (gp.fiber p "a" "a1")
    r
    (gp.fiber r "b" "b1")
  ];
  dunder = pg: lib.filter (lib.hasPrefix "__") (lib.attrNames pg);
in
{
  flake.tests.record-surface.test-no-undeclared-dunder-key = {
    expr = map dunder published;
    expected = [
      [ "__cells" ]
      [ "__cells" ]
      [ "__cells" ]
      [ "__cells" ]
    ];
  };
  flake.tests.record-surface.test-slice-keeps-ambient-definition = {
    expr = lib.attrNames ((gp.fiber p "a" "a1").product.def or { factorsByDim = { }; }).factorsByDim;
    expected = [
      "a"
      "b"
    ];
  };
  # The record cells cannot see the library's export set; a display helper that leaks into it is a
  # published name with no contract.
  flake.tests.record-surface.test-export-set = {
    expr = lib.attrNames genProduct;
    expected = [
      "cartesian"
      "cell"
      "cells"
      "containmentChain"
      "coordsOf"
      "fiber"
      "latticeGraph"
      "lexicographic"
      "linearizations"
      "linearizeByDimOrder"
      "productN"
      "projectTo"
      "quotient"
      "restrict"
      "show"
      "slice"
      "strong"
      "tensor"
    ];
  };
}
