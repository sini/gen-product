# adjacency-cartesian (law P1): `edges` of a cartesian product contains u -> v iff exactly one
# dimension is a factor edge and all others are equal. Verified against the brute-force oracle on mock
# factors, binary and 3-ary, including a self-loop factor.
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

  binFactors = [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gB)
  ];
  bin = gp.productN "cartesian" binFactors;

  triFactors = [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gB)
    (idFactor "z" fx.gChain)
  ];
  tri = gp.productN "cartesian" triFactors;

  loopFactors = [
    (idFactor "p" fx.gLoop)
    (idFactor "q" fx.gB)
  ];
  loop = gp.productN "cartesian" loopFactors;
in
{
  flake.tests.adjacency-cartesian = {
    test-binary-matches-oracle = {
      expr = implEdgeMap gp bin (gp.cells bin);
      expected = oracleEdgeMap gp bin "cartesian" binFactors (gp.cells bin);
    };
    test-ternary-matches-oracle = {
      expr = implEdgeMap gp tri (gp.cells tri);
      expected = oracleEdgeMap gp tri "cartesian" triFactors (gp.cells tri);
    };
    test-selfloop-matches-oracle = {
      expr = implEdgeMap gp loop (gp.cells loop);
      expected = oracleEdgeMap gp loop "cartesian" loopFactors (gp.cells loop);
    };
    # A concrete edge: (a0,b0) moves x → (a1,b0) and y → (a0,b1), nothing else.
    test-concrete-neighbours = {
      expr = lib.sort lib.lessThan (
        bin.edges (
          gp.cell bin {
            x = "a0";
            y = "b0";
          }
        )
      );
      expected = lib.sort lib.lessThan [
        (gp.cell bin {
          x = "a1";
          y = "b0";
        })
        (gp.cell bin {
          x = "a0";
          y = "b1";
        })
      ];
    };
  };
}
