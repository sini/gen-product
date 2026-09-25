# THE SECOND TEST OUTPUT — the cell whose `expr` CAN ABORT, and the runner that reads it.
#
# `test-not-a-node-throwing-entryof` pins that the fixture's real naive `entryOf = id: entries.${id}`
# (`ci/tests/_fixtures/graphs.nix`, binding `registryFactor`) raises an uncaught Nix EvalError on an unknown id_hash — that
# IS the point of the cell (MEASURED den-hoag-sq3i: `tryEval` does not catch a missing-attribute
# selection). `checks.default` (gen-harness's batch asserter, `flakeModule.nix:47-56`) forces every
# `expr` under `flake.tests` unconditionally and knows nothing of `expectedError`, so hosting this
# cell there crashed the whole gate rather than failing one cell (MEASURED batch-gate M-1, exec-gate
# report `den-hoag-burndown-batch1-exec-gate-v0.md`). It is therefore outside that tree by
# construction, on its own output — the pattern gen-graph's `ci/flake.nix:22-28` states and
# gen-harness's own `ci/tests-error.nix` practises.
#
#   nix-unit --flake ./ci#tests        # the suites (this cell excluded)
#   nix-unit --flake ./ci#testsError   # this cell
{
  lib,
  genProduct,
  prelude,
  graph,
  ...
}:
let
  fx = import ./tests/_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx)
    registryFactor
    defaultFactor
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

  # ── factor-doors (den-hoag-i25f) ──
  # The default codec (no `key`/`entryOf`) over gen-graph's total `fromRegistry` lookup.
  pDefault = gp.productN "cartesian" [
    (defaultFactor "host" hosts)
    (defaultFactor "user" users)
  ];
  # A factor whose `entryOf` REPRESENTS its partiality (explicit throw), overridden per cell so each
  # door is exercised with every other part of the spec well-formed.
  explicitHost = {
    dim = "host";
    graph = {
      nodes = builtins.attrNames hosts;
      edges = _: [ ];
      parent = _: null;
      nodeData = id: hosts.${id};
    };
    key = e: e.id_hash;
    entryOf = id: hosts.${id} or (throw "not a node: ${id}");
  };
  withHost =
    over:
    gp.productN "cartesian" [
      (explicitHost // over)
      uf
    ];
  goodCoords = {
    host = hosts.H_axon01;
    user = users.U_sini;
  };
  ghostHost = {
    host = {
      id_hash = "ghost";
      name = "ghost";
    };
    user = users.U_sini;
  };

  # not-a-node — the fixture's REAL naive idiom (`hf`/`p` above are built from `registryFactor`,
  # whose `entryOf = id: entries.${id}`) fed an unknown id_hash. The explicit-throw control and the
  # round-trip-mismatch scenario stay boolean and gate-safe, on `flake.tests`
  # (`ci/tests/identity-errors.nix`).
  notNodeNaiveUncaught = gp.cell p {
    host = {
      id_hash = "ghost";
      name = "ghost";
    };
    user = users.U_sini;
  };

  # malformed-membership — a relation pair lacking a dim of its relation, and a cell lacking a dim of
  # the product. Catchability (tryEval, both pair orders) is `ci/tests/restrict-membership.nix`.
  good = {
    host = hosts.H_axon01;
    user = users.U_sini;
  };
  bad = {
    host = hosts.H_axon02;
  };
  malformedPair = gp.cell (gp.restrict p {
    relations = [
      {
        dims = [
          "host"
          "user"
        ];
        pairs = [
          good
          bad
        ];
      }
    ];
  }) good;
  malformedCell = gp.cell (gp.restrict p {
    cells = [
      good
      bad
    ];
  }) good;
in
{
  config = {
    flake.testsError.identity-errors = {
      test-not-a-node-throwing-entryof = {
        expr = notNodeNaiveUncaught;
        expectedError = {
          type = "EvalError";
          msg = "attribute 'ghost' missing";
        };
      };
    };
    # Each door pinned BY MESSAGE: a lazy door yields the same tryEval table while misnaming the
    # refusal (a shape defect reported as `not-a-node`), so success alone does not discriminate.
    # `expectedError.msg` is a regex: parentheses are escaped.
    flake.testsError.factor-doors = {
      test-default-codec-non-node-refused-by-name = {
        expr = gp.cell pDefault ghostHost;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: not-a-node in dim 'host' — ghost";
        };
      };
      test-default-codec-non-attrset-refused-by-name = {
        expr = gp.cell pDefault (goodCoords // { host = "axon-01"; });
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: not-a-node in dim 'host' — <malformed-entry>";
        };
      };
      test-key-not-a-function = {
        expr = gp.cell (withHost { key = 5; }) goodCoords;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-factor — dim 'host': `key` is a int, not a function";
        };
      };
      test-entryof-not-a-function = {
        expr = gp.cell (withHost { entryOf = 5; }) goodCoords;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-factor — dim 'host': `entryOf` is a int, not a function";
        };
      };
      test-key-functor-not-a-function = {
        expr = gp.cell (withHost { key.__functor = 1; }) goodCoords;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-factor — dim 'host': `key` is a set, not a function";
        };
      };
      test-key-returns-a-non-id = {
        expr = gp.cell (withHost { key = _: x: x; }) goodCoords;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-factor — dim 'host': `key` returned a lambda, not a node id \\(a scalar\\)";
        };
      };
      test-entryof-named-pattern-formal = {
        expr = gp.cell (withHost { entryOf = { a }: a; }) goodCoords;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-factor — dim 'host': `entryOf` takes a node id \\(a scalar\\), which a pattern formal cannot accept";
        };
      };
      # ── RESIDUE (falsifiers): aborts inside a caller's function body, which gen-product cannot
      # observe. Each pins the abort as it stands; a door that starts catching one reds its cell.
      # `{ ... }` has no named formal (`functionArgs` is `{ }`, as for `x: …`), and a functor is not
      # a lambda, so the pattern-formal door cannot see either.
      test-residue-entryof-ellipsis-formal = {
        expr = gp.cell (withHost { entryOf = { ... }: hosts.H_axon01; }) goodCoords;
        expectedError = {
          type = "TypeError";
          msg = "expected a set but found a string: \"H_axon01\"";
        };
      };
      test-residue-entryof-functor-pattern-formal = {
        expr = gp.cell (withHost { entryOf.__functor = _: { a }: a; }) goodCoords;
        expectedError = {
          type = "TypeError";
          msg = "expected a set but found a string: \"H_axon01\"";
        };
      };
      test-residue-key-body-aborts = {
        expr = gp.cell (withHost { }) (goodCoords // { host = "axon-01"; });
        expectedError = {
          type = "TypeError";
          msg = "expected a set but found a string: \"axon-01\"";
        };
      };
    };
    # slice/fiber (den-hoag-qfcs3): a fixed coordinate that is not a node of its factor is refused by
    # the same named door as `cell`, naming the first offending dim in declared order.
    flake.testsError.slice-doors = {
      test-fiber-non-node-refused-by-name = {
        expr = (gp.fiber pDefault "host" ghostHost.host).nodes;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: not-a-node in dim 'host' — ghost";
        };
      };
      test-slice-non-node-refused-by-name = {
        expr =
          (gp.slice pDefault {
            host = hosts.H_axon01;
            user = ghostHost.host;
          }).nodes;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: not-a-node in dim 'user' — ghost";
        };
      };
    };
    flake.testsError.malformed-membership = {
      test-malformed-pair = {
        expr = malformedPair;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-membership — relations\\[0\\] \\(dims host, user\\) pair 1 lacks dim 'user' \\(has: host\\)";
        };
      };
      test-malformed-cell = {
        expr = malformedCell;
        expectedError = {
          type = "ThrownError";
          msg = "gen-product: malformed-membership — cells\\[1\\] lacks dim 'user' \\(has: host\\)";
        };
      };
    };
  };
}
