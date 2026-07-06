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
      lib = import ./lib {
        prelude = gen-prelude.lib;
      };
    };
}
