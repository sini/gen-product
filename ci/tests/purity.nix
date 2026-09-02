# Purity invariant (Class B, roadmap §2): the gen-product library (./lib) is nixpkgs-lib-free — it
# depends on gen-prelude only and imports no other gen library (its integration with gen-graph /
# gen-scope / gen-schema / gen-select is the shared accessor-record convention, not code). A stray
# `nixpkgs`/`lib.`/`evalModules` tether in the library source fails CI. Scope: lib/**.nix + the root
# flake.nix + default.nix (NOT ci/, whose harness legitimately uses nixpkgs.lib).
{ genPrelude, lib, ... }:
let
  libDir = ../../lib;

  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources =
    map (p: {
      name = toString p;
      code = stripComments (builtins.readFile p);
    }) (walk libDir)
    ++
      map
        (rel: {
          name = rel;
          code = stripComments (builtins.readFile (../.. + "/${rel}"));
        })
        [
          "flake.nix"
          "default.nix"
        ];

  forbidden = [
    "nixpkgs"
    # The BOUNDARY: any nixpkgs lib call at all. The named `lib.X` entries below are kept for
    # the sharper message they give on a red, not because they bound the invariant.
    "lib."
    "lib.types"
    "lib.mkOption"
    "lib.mkMerge"
    "lib.mkForce"
    "lib.evalModules"
    "evalModules"
    "{ lib }"
    "{ lib,"
  ];

  violations = lib.concatMap (
    src:
    map (tok: "${src.name}: '${tok}'") (lib.filter (tok: genPrelude.hasInfix tok src.code) forbidden)
  ) sources;
in
{
  flake.tests.purity.test-library-source-is-nixpkgs-free = {
    expr = violations;
    expected = [ ];
  };
}
