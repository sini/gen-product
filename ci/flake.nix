{
  inputs = {
    gen.url = "github:sini/gen";
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
      gen,
      gen-prelude,
      gen-graph,
      ...
    }:
    let
      genProduct = import ../lib {
        prelude = gen-prelude.lib;
      };
    in
    gen.lib.mkCi {
      inherit inputs;
      name = "gen-product";
      testModules = ./tests;
      specialArgs = {
        inherit genProduct;
        graph = gen-graph.lib;
      };
    };
}
