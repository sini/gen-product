# identity-errors (law P15): public inputs are registry entries (or caller-keyed ids via explicit
# `key`); no public function accepts a "kind:name" string. Every §4.6 addressing error is a
# definition-time throw. not-a-node detection fixtures: throwing `entryOf`, round-trip-mismatching
# `entryOf`, and the VACUOUS identity-codec path (a non-node passes `cell`, pinned as documented
# behaviour). Entries-in / entries-out audit of the public surface.
#
# Note: Nix `tryEval` reports only whether a throw fired, not its text; the messages themselves name
# the dimension and render the offending value by construction (lib/view.nix, lib/show.nix).
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx)
    registryFactor
    idFactor
    hosts
    users
    ;
  gp = genProduct;

  hf = registryFactor "host" hosts;
  uf = registryFactor "user" users;
  p = gp.productN "cartesian" [
    hf
    uf
  ];

  fails = e: !(builtins.tryEval e).success;

  # duplicate-dim: two factors share a dim.
  dupDim = fails (
    gp.productN "cartesian" [
      hf
      (registryFactor "host" users)
    ]
  );
  # unknown-kind.
  badKind = fails (
    gp.productN "octahedral" [
      hf
      uf
    ]
  );
  # unknown-dim: coords reference an undeclared dim.
  unknownDim = fails (
    gp.cell p {
      host = hosts.H_axon01;
      user = users.U_sini;
      env = users.U_vic;
    }
  );
  # missing-dim: partial coords to cell.
  missingDim = fails (gp.cell p { host = hosts.H_axon01; });

  # not-a-node — (b) throwing entryOf.
  throwEntryOf = {
    dim = "host";
    graph = {
      nodes = builtins.attrNames hosts;
      edges = _: [ ];
      parent = _: null;
      nodeData = id: hosts.${id};
    };
    key = e: e.id_hash;
    entryOf = id: if id == "ghost" then throw "no such host" else hosts.${id};
  };
  pThrow = gp.productN "cartesian" [
    throwEntryOf
    uf
  ];
  notNodeThrow = fails (
    gp.cell pThrow {
      host = {
        id_hash = "ghost";
        name = "ghost";
      };
      user = users.U_sini;
    }
  );

  # not-a-node — (c) round-trip-mismatching entryOf (always returns a fixed wrong entry).
  mismatchEntryOf = throwEntryOf // {
    entryOf = _: {
      id_hash = "WRONG";
      name = "wrong";
    };
  };
  pMismatch = gp.productN "cartesian" [
    mismatchEntryOf
    uf
  ];
  notNodeMismatch = fails (
    gp.cell pMismatch {
      host = hosts.H_axon01;
      user = users.U_sini;
    }
  );

  # VACUOUS identity-codec path: a non-node id passes `cell` (round-trip trivially holds).
  idProd = gp.productN "cartesian" [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gB)
  ];
  vacuous =
    (builtins.tryEval (
      gp.cell idProd {
        x = "not-a-real-node";
        y = "b0";
      }
    )).success;

  # not-a-member on a restricted product.
  restricted = gp.restrict p {
    cells = [
      {
        host = hosts.H_axon01;
        user = users.U_sini;
      }
    ];
  };
  notMember = fails (
    gp.cell restricted {
      host = hosts.H_blade01;
      user = users.U_vic;
    }
  );

  # entries-in / entries-out audit: coordsOf returns registry ENTRIES (id_hash + name), not strings.
  recovered = gp.coordsOf p (
    gp.cell p {
      host = hosts.H_axon02;
      user = users.U_vic;
    }
  );
in
{
  flake.tests.identity-errors = {
    test-duplicate-dim = {
      expr = dupDim;
      expected = true;
    };
    test-unknown-kind = {
      expr = badKind;
      expected = true;
    };
    test-unknown-dim = {
      expr = unknownDim;
      expected = true;
    };
    test-missing-dim = {
      expr = missingDim;
      expected = true;
    };
    test-not-a-node-throwing-entryof = {
      expr = notNodeThrow;
      expected = true;
    };
    test-not-a-node-roundtrip-mismatch = {
      expr = notNodeMismatch;
      expected = true;
    };
    # documented: the identity codec cannot distinguish non-nodes → cell succeeds (vacuous detection).
    test-identity-codec-vacuous = {
      expr = vacuous;
      expected = true;
    };
    test-not-a-member = {
      expr = notMember;
      expected = true;
    };
    # entries-out: coordinates recovered as full registry entries.
    test-entries-out-are-entries = {
      expr = {
        host = {
          inherit (recovered.host) id_hash name;
        };
        user = {
          inherit (recovered.user) id_hash name;
        };
      };
      expected = {
        host = {
          id_hash = "H_axon02";
          name = "axon-02";
        };
        user = {
          id_hash = "U_vic";
          name = "vic";
        };
      };
    };
    # entries-in: the public codec accepts entries (never a "kind:name" string) — round-trip witness.
    test-entries-in-accepted = {
      expr =
        gp.cell p (
          gp.coordsOf p (
            gp.cell p {
              host = hosts.H_axon01;
              user = users.U_sini;
            }
          )
        ) == gp.cell p {
          host = hosts.H_axon01;
          user = users.U_sini;
        };
      expected = true;
    };
  };
}
