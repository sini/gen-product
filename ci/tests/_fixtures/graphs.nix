# Shared test fixtures: mock factor graphs, registry-entry factors, and a BRUTE-FORCE adjacency oracle
# recomputed independently of the library under test (so every adjacency law is checked against a
# separate source of truth, not the implementation restated).
{ lib, graph }:
let
  inherit (builtins) listToAttrs elem;

  # A directed graph with explicit node order (order is load-bearing for enumeration/lex goldens).
  mkDigraph =
    { nodes, edges }:
    {
      inherit nodes;
      edges = id: map (e: e.to) (lib.filter (e: e.from == id) edges);
      parent = _: null;
      nodeData = id: id;
    };

  e = from: to: { inherit from to; };

  # ── identity-codec factor (coordinates ARE node ids) ──
  idFactor = dim: g: {
    inherit dim;
    graph = g;
    key = id: id;
    entryOf = id: id;
  };

  # ── registry-entry factor (coordinates are entries; key = id_hash; entryOf throws on unknown) ──
  registryFactor = dim: entries: {
    inherit dim;
    graph = {
      nodes = builtins.attrNames entries;
      edges = _: [ ];
      parent = _: null;
      nodeData = id: entries.${id};
    };
    key = entry: entry.id_hash;
    # attrset access on an unknown id_hash raises an uncaught Nix EvalError ("attribute '<id>'
    # missing"), NOT a catchable `throw` — `tryEval` does not catch it (MEASURED den-hoag-sq3i), so
    # pointwise not-a-node detection's own `tryEval (lib/view.nix)` cannot catch it either: this
    # idiom currently BYPASSES not-a-node detection rather than satisfying its precondition. Pinned
    # live at ci/tests/identity-errors.nix:test-not-a-node-throwing-entryof. Making the idiom
    # catchable is a mechanism fix tracked separately (den-hoag-i25f).
    entryOf = id: entries.${id};
  };

  # Mock directed graphs.
  gA = mkDigraph {
    nodes = [
      "a0"
      "a1"
    ];
    edges = [ (e "a0" "a1") ]; # a path, no loop
  };
  gB = mkDigraph {
    nodes = [
      "b0"
      "b1"
    ];
    edges = [
      (e "b0" "b1")
      (e "b1" "b0")
    ]; # symmetric
  };
  gLoop = mkDigraph {
    nodes = [
      "l0"
      "l1"
    ];
    edges = [
      (e "l0" "l1")
      (e "l0" "l0")
    ]; # self-loop on l0
  };
  gChain = mkDigraph {
    nodes = [
      "c0"
      "c1"
      "c2"
    ];
    edges = [
      (e "c0" "c1")
      (e "c1" "c2")
    ];
  };
  # K2 as a symmetric digraph — the golden-classics factor.
  k2 = mkDigraph {
    nodes = [
      "u"
      "v"
    ];
    edges = [
      (e "u" "v")
      (e "v" "u")
    ];
  };

  # Registry entries.
  mkEntry =
    h: name: extra:
    {
      id_hash = h;
      inherit name;
    }
    // extra;
  hosts = {
    "H_axon01" = mkEntry "H_axon01" "axon-01" { class = classCortex; };
    "H_axon02" = mkEntry "H_axon02" "axon-02" { class = classCortex; };
    "H_blade01" = mkEntry "H_blade01" "blade-01" { class = classBlade; };
  };
  classCortex = {
    id_hash = "C_cortex";
    name = "cortex";
  };
  classBlade = {
    id_hash = "C_blade";
    name = "blade";
  };
  users = {
    "U_sini" = mkEntry "U_sini" "sini" { };
    "U_vic" = mkEntry "U_vic" "vic" { };
  };
  envs = {
    "E_prod" = mkEntry "E_prod" "prod" { };
    "E_dev" = mkEntry "E_dev" "dev" { };
  };

  # ── brute-force adjacency oracle (independent of lib/adjacency.nix) ──
  edgeIn =
    g: a: b:
    elem b (g.edges a);

  # u, v are coords (dim -> node id); factorsList is the ordered [ idFactor ] list.
  oraclePred =
    kind: factorsList: u: v:
    let
      dims = map (f: f.dim) factorsList;
      fb = listToAttrs (
        map (f: {
          name = f.dim;
          value = f;
        }) factorsList
      );
      hasEdge = d: edgeIn fb.${d}.graph u.${d} v.${d};
      eq = d: u.${d} == v.${d};
      n = lib.length dims;
      idx = lib.range 0 (n - 1);
      at = i: lib.elemAt dims i;
    in
    if kind == "cartesian" then
      # ∃ exactly-one moving dim j with an edge; all others equal.
      lib.any (j: hasEdge (at j) && lib.all (i: i == j || eq (at i)) idx) idx
    else if kind == "tensor" then
      lib.all (d: hasEdge d) dims
    else if kind == "strong" then
      lib.all (d: eq d || hasEdge d) dims && lib.any (d: hasEdge d) dims
    # lexicographic
    else
      lib.any (j: (lib.all (i: eq (at i)) (lib.range 0 (j - 1))) && hasEdge (at j)) idx;

  # Edge map of the product under test: { cellId = sorted [ cellId ]; }.
  implEdgeMap =
    gp: p: cellsList:
    listToAttrs (
      map (c: {
        name = p.product.cellOf c;
        value = lib.sort lib.lessThan (p.edges (p.product.cellOf c));
      }) cellsList
    );

  # Edge map from the oracle over the same cell list.
  oracleEdgeMap =
    gp: p: kind: factorsList: cellsList:
    listToAttrs (
      map (u: {
        name = p.product.cellOf u;
        value = lib.sort lib.lessThan (
          map (v: p.product.cellOf v) (lib.filter (v: oraclePred kind factorsList u v) cellsList)
        );
      }) cellsList
    );
in
{
  inherit
    mkDigraph
    idFactor
    registryFactor
    gA
    gB
    gLoop
    gChain
    k2
    hosts
    users
    envs
    classCortex
    classBlade
    oraclePred
    implEdgeMap
    oracleEdgeMap
    e
    ;
}
