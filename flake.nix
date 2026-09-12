{
  description = "gen-product — graph products as first-class operations over accessor-graphs (Cartesian / tensor / strong / lexicographic; cells, slices, fibers, projections, quotients, restriction, containment chains), lazy in and out";

  # Class layering: gen-prelude → gen-product (Class B). gen-product consumes gen-prelude ONLY (the
  # pure utility base); it is nixpkgs-lib-free (ci/tests/purity.nix) and imports no other gen library —
  # its entire integration story with gen-graph, gen-scope, gen-schema, gen-select is the shared
  # accessor-record convention { edges, parent, nodes, nodeData } and the gen-schema instance shape
  # (id_hash, name), conventions rather than code dependencies.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";
  };

  outputs =
    { gen-prelude, ... }:
    {
      # `nix flake check` forces the WHNF of every top-level output and nothing deeper, so this root's
      # green quantified over the `lib` SPINE alone: a member of the published surface could throw and
      # the check still exited 0 (measured — den-hoag-z1ta6). Hanging the force on that spine is what
      # makes the green mean "the surface evaluates", and a library needs no new output name for it.
      # The depth is each member's WHNF and no deeper: a retirement tombstone is a published `throw`
      # by design (gen-scope's `buildNodes`), so a deep force is red on a healthy tree.
      lib =
        let
          surface = import ./lib {
            prelude = gen-prelude.lib;
          };
        in
        builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) surface) surface;
    };
}
