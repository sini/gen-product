# lattice-graph (feature #2): the subset/specificity lattice 2^D exposed as its COVERING relation (the
# Hasse diagram). For a dimension set D the subsets S ⊆ D form the boolean lattice — ∅ (least specific,
# the whole product) to D (most specific, the cell). The covering relation is S ⋖ S∪{d} for each
# d ∈ D\S: one dim-labeled edge per added dimension. `latticeGraph` returns { nodes; edges } with edges
# in den's node.query-traversable flat labeled shape `[{ kind; from; to }]` (kind = the added dim, ids =
# `showSubset`). Structure only — no linearization baked in (that is a separate ordering discipline).
{
  lib,
  genProduct,
  ...
}:
let
  gp = genProduct;

  # canonical string key for an edge, so an edge SET can be compared order-independently.
  edgeKey = e: "${e.from}|${e.kind}|${e.to}";
  sortEdges = lib.sort (a: b: edgeKey a < edgeKey b);
  sortStr = lib.sort lib.lessThan;

  ab = gp.latticeGraph [
    "a"
    "b"
  ];
  a1 = gp.latticeGraph [ "a" ];
  d0 = gp.latticeGraph [ ];
in
{
  flake.tests.lattice-graph = {
    # D = [ a b ]: the boolean lattice 2^{a,b} has exactly the four subsets as nodes.
    test-ab-nodes = {
      expr = sortStr ab.nodes;
      expected = sortStr [
        "{}"
        "{a}"
        "{b}"
        "{a,b}"
      ];
    };
    # …and exactly four covering edges, each labeled by the single added dimension:
    #   {}→{a} (a), {}→{b} (b), {a}→{a,b} (b), {b}→{a,b} (a).
    test-ab-edges = {
      expr = sortEdges ab.edges;
      expected = sortEdges [
        {
          kind = "a";
          from = "{}";
          to = "{a}";
        }
        {
          kind = "b";
          from = "{}";
          to = "{b}";
        }
        {
          kind = "b";
          from = "{a}";
          to = "{a,b}";
        }
        {
          kind = "a";
          from = "{b}";
          to = "{a,b}";
        }
      ];
    };
    test-ab-edge-count = {
      expr = lib.length ab.edges;
      expected = 4;
    };
    # every edge `to` resolves to an existing node id (S∪{d} normalized to the same D-order keying).
    test-ab-edges-close = {
      expr = lib.all (e: lib.elem e.to ab.nodes && lib.elem e.from ab.nodes) ab.edges;
      expected = true;
    };
    # boundary: D = [ a ] — two nodes, one covering edge.
    test-singleton = {
      expr = {
        nodes = sortStr a1.nodes;
        edges = a1.edges;
      };
      expected = {
        nodes = sortStr [
          "{}"
          "{a}"
        ];
        edges = [
          {
            kind = "a";
            from = "{}";
            to = "{a}";
          }
        ];
      };
    };
    # boundary: D = [ ] — the singleton lattice {∅}, one node, no edges.
    test-empty = {
      expr = {
        inherit (d0) nodes edges;
      };
      expected = {
        nodes = [ "{}" ];
        edges = [ ];
      };
    };
  };
}
