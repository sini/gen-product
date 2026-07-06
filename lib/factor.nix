# gen-product — lib/factor.nix : factor-spec normalization.
#
# A product constructor takes FACTOR SPECS, not bare graphs, because dimensions are named and
# coordinates are registry entries (the identity law: public inputs carry gen-schema identity,
# never "kind:name" strings). A factor spec is
#
#   { dim; graph; key ? (entry: entry.id_hash); entryOf ? graph.nodeData; }
#
# `key` maps a public coordinate value (a registry entry) to the factor graph's node id (an internal
# key); `entryOf` is its inverse. The default assumes gen-schema instances keyed by `id_hash`.
#
# As a convenience a BARE accessor-graph is accepted where a factor spec is expected: its `dim`
# defaults to its positional index rendered as a string and coordinates ARE the node ids
# (`key = id: id`, `entryOf = id: id`). This identity codec cannot distinguish non-nodes pointwise,
# so not-a-node detection is vacuous on this path — den never uses it (identity law); it exists for
# generic-graph callers.
{ prelude }:
let
  inherit (prelude) imap0 map;
  inherit (builtins) toString;

  # A value is a factor spec iff it carries a `graph` field; a bare accessor-graph never does
  # (it carries edges/parent/nodes/nodeData). The discriminator is total on both shapes.
  isFactorSpec = spec: spec ? graph;

  normalizeFactor =
    idx: spec:
    if isFactorSpec spec then
      {
        inherit (spec) dim graph;
        key = spec.key or (entry: entry.id_hash);
        entryOf = spec.entryOf or spec.graph.nodeData;
      }
    else
      {
        dim = toString idx;
        graph = spec;
        key = id: id;
        entryOf = id: id;
      };

  normalizeFactors = factors: imap0 normalizeFactor factors;
in
{
  inherit normalizeFactor normalizeFactors;
}
