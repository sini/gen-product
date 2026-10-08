# The grammar's L1 rows here (den-hoag-7gp66 O3, R8): a product's cell is its node, so `cell` is
# `nodeAt` and `cells` is `nodeCoordinates`. The old names refuse catchably (their messages are
# pinned by the generated `root-surface-retired.*` cells), and each successor serves: it agrees with
# the node set on one coordinate and differs on another.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) registryFactor hosts users;
  gp = genProduct;
  p = gp.productN "cartesian" [
    (registryFactor "host" hosts)
    (registryFactor "user" users)
  ];
  refuses = v: !(builtins.tryEval (builtins.typeOf v)).success;
  a = {
    host = hosts.H_axon01;
    user = users.U_sini;
  };
  b = a // {
    user = users.U_vic;
  };
in
{
  flake.tests.grammar-renames.test-old-names-refuse = {
    expr = map refuses [
      gp.cell
      gp.cells
    ];
    expected = [
      true
      true
    ];
  };

  flake.tests.grammar-renames.test-successors-serve = {
    expr = {
      # `nodeCoordinates` enumerates exactly the product's nodes, in `nodes` order
      enumerates = map (c: gp.nodeAt c p) (gp.nodeCoordinates p) == p.nodes;
      # `nodeAt` agrees with the round trip on one coordinate, and differs across two
      agrees = gp.coordsOf (gp.nodeAt a p) p == a;
      differs = gp.nodeAt a p == gp.nodeAt b p;
    };
    expected = {
      enumerates = true;
      agrees = true;
      differs = false;
    };
  };
}
