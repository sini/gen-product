# gen-product — lib/membership.nix : the membership relation of a restricted (sparse) sub-product,
# plus lattice enumeration.
#
# A membership record is data — { cells ? null; relations ? [ ]; predicate ? (_: true); }. `restrict`
# CONSUMES it; emitting membership from policies is den-hoag wiring, never this library's concern
# (structural stratum only). A cell c is a member iff all three clauses hold (§2.6):
#   1. cells == null OR c ∈ cells (by cellId);
#   2. for every relation r, the projection of c onto r.dims occurs in r.pairs (natural join —
#      relations conjoin, pairs within a relation are alternatives);
#   3. predicate (coords of c) is true.
#
# Enumeration follows a normative order of preference (strategies 1/2/3) so that a well-specified
# sparse fleet never materializes the full product; the adjacency path uses only the point test
# `isMember`, so `edges` of a predicate-restricted product never enumerates (law P11).
{ prelude }:
let
  inherit (prelude)
    map
    filter
    elem
    elemAt
    foldl'
    concatMap
    all
    unique
    tail
    ;
  inherit (builtins) toJSON;

  # A `def` here is { kind; dims; factorsByDim; factorsList; }.
  keyTuple =
    def: dims: coords:
    map (d: (def.factorsByDim.${d}).key coords.${d}) dims;

  fullCellId = def: coords: toJSON (keyTuple def def.dims coords);

  normalizeMembership = m: {
    cells = m.cells or null;
    relations = m.relations or [ ];
    predicate = m.predicate or (_: true);
  };

  relationMatch =
    def: relation: coords:
    let
      projd = toJSON (keyTuple def relation.dims coords);
      pairKeys = map (p: toJSON (keyTuple def relation.dims p)) relation.pairs;
    in
    elem projd pairKeys;

  # Point test — the strategy-free membership oracle used on the adjacency path (never enumerates).
  isMember =
    def: restriction: coords:
    if restriction == null then
      true
    else
      let
        c1 =
          restriction.cells == null || elem (fullCellId def coords) (map (fullCellId def) restriction.cells);
        c2 = all (r: relationMatch def r coords) restriction.relations;
        c3 = restriction.predicate coords;
      in
      c1 && c2 && c3;

  # Conjoin two normalized restrictions (restrict∘restrict — the induced-subgraph intersection). The
  # combined record stays cells/relations-shaped so enumeration keeps its hints; both cells clauses
  # are additionally re-checked in the predicate so no member escapes either constraint.
  conjoin = def: r: m: {
    cells = if m.cells != null then m.cells else r.cells;
    relations = r.relations ++ m.relations;
    predicate =
      c:
      r.predicate c
      && m.predicate c
      && (r.cells == null || elem (fullCellId def c) (map (fullCellId def) r.cells))
      && (m.cells == null || elem (fullCellId def c) (map (fullCellId def) m.cells));
  };

  # Full row-major lattice enumeration: declared factor order, last dimension varying fastest, each
  # factor's own `nodes` order preserved (law P14). Forces every factor node list (en-masse, law P10).
  enumerateFull =
    def:
    foldl' (
      acc: d:
      let
        f = def.factorsByDim.${d};
        entries = map (id: f.entryOf id) f.graph.nodes;
      in
      concatMap (partial: map (e: partial // { ${d} = e; }) entries) acc
    ) [ { } ] def.dims;

  firstSeenBy =
    keyFn: xs: foldl' (acc: x: if elem (keyFn x) (map keyFn acc) then acc else acc ++ [ x ]) [ ] xs;

  relationsCoverAll =
    def: restriction:
    let
      covered = unique (concatMap (r: r.dims) restriction.relations);
    in
    restriction.relations != [ ] && all (d: elem d covered) def.dims;

  # Strategy 2 — relational join. Seed with the first declared relation's pairs, extend each partial
  # tuple across the remaining relations in declared order (shared dims must agree). Deterministic and
  # never materializes the full product.
  joinEnumerate =
    def: restriction:
    let
      relations = restriction.relations;
      seed = (elemAt relations 0).pairs;
      extend =
        acc: r:
        concatMap (
          partial:
          filter (x: x != null) (
            map (
              pair:
              let
                shared = filter (d: builtins.hasAttr d partial) r.dims;
                ok = all (
                  d: (def.factorsByDim.${d}).key partial.${d} == (def.factorsByDim.${d}).key pair.${d}
                ) shared;
              in
              if ok then partial // pair else null
            ) r.pairs
          )
        ) acc;
      joined = foldl' extend seed (tail relations);
    in
    firstSeenBy (fullCellId def) (filter restriction.predicate joined);

  enumerateMembers =
    def: restriction:
    if restriction == null then
      enumerateFull def
    else if restriction.cells != null then
      # Strategy 1 — explicit cells, first-seen deduplicated by cellId, given order preserved
      # (no silent reorder, B5 discipline), then filtered by clauses (2) and (3).
      filter (isMember def restriction) (firstSeenBy (fullCellId def) restriction.cells)
    else if relationsCoverAll def restriction then
      joinEnumerate def restriction
    else
      # Strategy 3 — filter the full-product enumeration. Documented O(Π |V_i|) cost.
      filter (isMember def restriction) (enumerateFull def);
in
{
  inherit
    keyTuple
    fullCellId
    normalizeMembership
    isMember
    conjoin
    enumerateFull
    enumerateMembers
    firstSeenBy
    ;
}
