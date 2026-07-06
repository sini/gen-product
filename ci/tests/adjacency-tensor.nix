# adjacency-tensor (law P2): edge iff EVERY dimension is a factor edge. Same oracle harness as P1.
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
    (idFactor "x" fx.gB)
    (idFactor "y" fx.gB)
  ];
  bin = gp.productN "tensor" binFactors;

  triFactors = [
    (idFactor "x" fx.gB)
    (idFactor "y" fx.gB)
    (idFactor "z" fx.gChain)
  ];
  tri = gp.productN "tensor" triFactors;

  loopFactors = [
    (idFactor "p" fx.gLoop)
    (idFactor "q" fx.gB)
  ];
  loop = gp.productN "tensor" loopFactors;
in
{
  flake.tests.adjacency-tensor = {
    test-binary-matches-oracle = {
      expr = implEdgeMap gp bin (gp.cells bin);
      expected = oracleEdgeMap gp bin "tensor" binFactors (gp.cells bin);
    };
    test-ternary-matches-oracle = {
      expr = implEdgeMap gp tri (gp.cells tri);
      expected = oracleEdgeMap gp tri "tensor" triFactors (gp.cells tri);
    };
    test-selfloop-matches-oracle = {
      expr = implEdgeMap gp loop (gp.cells loop);
      expected = oracleEdgeMap gp loop "tensor" loopFactors (gp.cells loop);
    };
    # (b0,b0) advances both dims → (b1,b1) only.
    test-concrete-both-advance = {
      expr = bin.edges (
        gp.cell bin {
          x = "b0";
          y = "b0";
        }
      );
      expected = [
        (gp.cell bin {
          x = "b1";
          y = "b1";
        })
      ];
    };
  };
}
