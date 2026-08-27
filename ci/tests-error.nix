# THE SECOND TEST OUTPUT — the cell whose `expr` CAN ABORT, and the runner that reads it.
#
# `test-not-a-node-throwing-entryof` pins that the fixture's real naive `entryOf = id: entries.${id}`
# (`ci/tests/_fixtures/graphs.nix:44`) raises an uncaught Nix EvalError on an unknown id_hash — that
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
  genInputs,
  ...
}:
let
  fx = import ./tests/_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) registryFactor hosts users;
  gp = genProduct;

  hf = registryFactor "host" hosts;
  uf = registryFactor "user" users;
  p = gp.productN "cartesian" [
    hf
    uf
  ];

  # not-a-node — the fixture's REAL naive idiom (`hf`/`p` above are built from `registryFactor`,
  # whose `entryOf = id: entries.${id}` — graphs.nix:44) fed an unknown id_hash. The explicit-throw
  # control and the round-trip-mismatch scenario stay boolean and gate-safe, on `flake.tests`
  # (`ci/tests/identity-errors.nix`).
  notNodeNaiveUncaught = gp.cell p {
    host = {
      id_hash = "ghost";
      name = "ghost";
    };
    user = users.U_sini;
  };
in
{
  # Same type as `flake.tests` (`gen-harness/flakeModule.nix`), because it is the same kind of thing
  # read by the same runner — only the assertion the cell carries differs.
  options.flake.testsError = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.raw);
    default = { };
    description = "Test suites whose cells' `expr` CAN ABORT: { suite.test = { expr; expected | expectedError; }; }. Read by `nix-unit --flake ./ci#testsError`; deliberately outside `flake.tests`, which the batch asserter forces every `expr` of and would crash on rather than fail.";
  };

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

    # THE SECOND HOOK. A second output that nothing runs is a second output that rots, and the
    # `ci` hook `gen-harness/flakeModule.nix` builds bakes `./ci#tests` into its own text, so it
    # cannot be pointed here. This is its counterpart, under a distinct hook id so the two merge
    # rather than collide.
    perSystem =
      { pkgs, system, ... }:
      {
        pre-commit.settings.hooks.ci-error = {
          enable = true;
          name = "ci-error";
          description = "Run nix-unit error-assertion tests";
          entry = "${
            pkgs.writeShellApplication {
              name = "gen-product-ci-nix-unit-error";
              runtimeInputs = [ genInputs.nix-unit.packages.${system}.default ];
              text = ''
                exec nix-unit --flake ./ci#testsError "$@"
              '';
            }
          }/bin/gen-product-ci-nix-unit-error";
          files = "\\.nix$";
          pass_filenames = false;
        };
      };
  };
}
