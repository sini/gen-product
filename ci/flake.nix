{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";
    gen-prelude.url = "github:sini/gen-prelude";
    # gen-graph is a DEV dependency only: the test suites build mock factor graphs with its
    # `mkGraph` helper and consume its accessor record. It enters ONLY here (a VALUE in ci/), never a
    # `lib/` dep — the library (../lib) imports no gen library beyond gen-prelude (ci/tests/purity.nix).
    gen-graph.url = "github:sini/gen-graph";
    # nixpkgs is the CI runner's dependency (nix-unit harness, treefmt) and supplies the `lib` the test
    # modules use for oracle scaffolding. It enters ONLY here, never a `lib/` dep.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-prelude,
      gen-graph,
      ...
    }:
    let
      prelude = gen-prelude.lib;
      genProduct = import ../lib { inherit prelude; };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-product";
      testModules = ./tests;
      # `prelude` reaches the suite because `tests/entry.nix` applies the STANDALONE root entry with
      # explicit arguments — which is what keeps that cell pure, since supplying the formal means the
      # shim's fetching default is never forced. It is the SAME instance `genProduct` above is built
      # from, so the two sides of that comparison differ in entry point and in nothing else.
      specialArgs = {
        inherit genProduct prelude;
        graph = gen-graph.lib;
      };
      # Cells whose `expr` CAN ABORT go on a second output, outside the `flake.tests` quantifier
      # `checks.default` forces unconditionally — see `./tests-error.nix`.
      extraModules = [ ./tests-error.nix ];
    };
}
