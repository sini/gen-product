# factor-doors (den-hoag-i25f): the boolean, gate-safe half of the factor-spec doors. The refusals
# themselves are pinned BY MESSAGE on `../tests-error.nix` (`factor-doors`), because a success-only
# table cannot tell a named refusal from a misattributed one.
#
# - The default codec's not-a-node is CATCHABLE: `key` defaults to a door that throws on a
#   coordinate without `id_hash`, so `notANode`'s `tryEval` observes it and `cell` refuses by name.
# - The default codec still addresses a real node, with and without a restriction (live controls).
# - Scalar node ids that are not strings keep addressing: the result door refuses only what
#   gen-graph's `nodeKey` refuses (set, list, function, null), so an INTEGER id works, on a factor
#   spec and on a bare accessor-graph. This does not settle which scalars are node ids
#   (den-hoag-3w9e7); it pins that this door is no narrower than gen-graph's.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx)
    defaultFactor
    registryFactor
    hosts
    users
    ;
  gp = genProduct;

  pDefault = gp.productN "cartesian" [
    (defaultFactor "host" hosts)
    (defaultFactor "user" users)
  ];
  good = {
    host = hosts.H_axon01;
    user = users.U_sini;
  };
  ghost = {
    id_hash = "ghost";
    name = "ghost";
  };

  # Integer node ids under an explicit, total codec.
  ints = [
    {
      n = 0;
      name = "zero";
    }
    {
      n = 1;
      name = "one";
    }
  ];
  intFactor = {
    dim = "host";
    graph = {
      nodes = [
        0
        1
      ];
      edges = _: [ ];
      parent = _: null;
      nodeData = i: builtins.elemAt ints i;
    };
    key = e: e.n;
    entryOf =
      i: if builtins.isInt i && i >= 0 && i < 2 then builtins.elemAt ints i else throw "not a node";
  };
  pInt = gp.productN "cartesian" [
    intFactor
    (registryFactor "user" users)
  ];

  # Integer node ids on a bare accessor-graph (gen-product's own identity codec).
  bare = nodes: {
    inherit nodes;
    edges = _: [ ];
    parent = _: null;
    nodeData = _: { };
  };
  pBareInt = gp.productN "cartesian" [
    (bare [
      0
      1
    ])
    (bare [
      "a"
      "b"
    ])
  ];
in
{
  flake.tests.factor-doors = {
    test-default-codec-not-a-node-is-catchable = {
      expr =
        !(builtins.tryEval (
          builtins.deepSeq (gp.cell pDefault {
            host = ghost;
            user = users.U_sini;
          }) true
        )).success;
      expected = true;
    };
    test-default-codec-addresses-a-node = {
      expr = gp.cell pDefault good;
      expected = "[\"H_axon01\",\"U_sini\"]";
    };
    test-default-codec-restricted-addresses-a-member = {
      expr = gp.cell (gp.restrict pDefault { cells = [ good ]; }) good;
      expected = "[\"H_axon01\",\"U_sini\"]";
    };
    test-int-node-id-addresses = {
      expr = gp.cell pInt {
        host = builtins.elemAt ints 1;
        user = users.U_sini;
      };
      expected = "[1,\"U_sini\"]";
    };
    test-int-node-id-enumerated = {
      expr = pInt.nodes;
      expected = [
        "[0,\"U_sini\"]"
        "[0,\"U_vic\"]"
        "[1,\"U_sini\"]"
        "[1,\"U_vic\"]"
      ];
    };
    # slice/fiber (den-hoag-qfcs3): a fixed coordinate passes the same not-a-node door as `cell`,
    # so a non-node is a CATCHABLE refusal (named on `../tests-error.nix`, `slice-doors`), never an
    # empty fiber at rc 0. Controls: a real node's fiber and slice, and an integer-id fiber.
    test-fiber-non-node-is-catchable = {
      expr = !(builtins.tryEval (builtins.deepSeq (gp.fiber pDefault "host" ghost).nodes true)).success;
      expected = true;
    };
    test-slice-non-node-is-catchable = {
      expr =
        !(builtins.tryEval (
          builtins.deepSeq
            (gp.slice pDefault {
              host = hosts.H_axon01;
              user = ghost;
            }).nodes
            true
        )).success;
      expected = true;
    };
    test-fiber-real-node = {
      expr = (gp.fiber pDefault "host" hosts.H_axon01).nodes;
      expected = [
        "[\"U_sini\"]"
        "[\"U_vic\"]"
      ];
    };
    test-slice-real-nodes = {
      expr = (gp.slice pDefault good).nodes;
      expected = [ "[]" ];
    };
    test-int-node-id-fiber = {
      expr = (gp.fiber pInt "host" (builtins.elemAt ints 1)).nodes;
      expected = [
        "[\"U_sini\"]"
        "[\"U_vic\"]"
      ];
    };
    test-int-bare-accessor-addresses = {
      expr = gp.cell pBareInt {
        "0" = 1;
        "1" = "a";
      };
      expected = "[1,\"a\"]";
    };
  };
}
