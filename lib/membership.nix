# gen-product — lib/membership.nix : the membership relation of a restricted (sparse) sub-product,
# plus lattice enumeration.
#
# A membership record is data — { cells ? null; relations ? [ ]; predicate ? (_: true); }. `restrict`
# CONSUMES it; emitting membership from policies is den-hoag wiring, never this library's concern
# (structural stratum only). A cell c is a member iff all three clauses hold:
#   1. cells == null OR c ∈ cells (by cellId);
#   2. for every relation r, the projection of c onto r.dims occurs in r.pairs (natural join —
#      relations conjoin, pairs within a relation are alternatives);
#   3. predicate (coords of c) is true.
#
# Enumeration follows a normative order of preference (strategies 1/2/3) so that a well-specified
# sparse fleet never materializes the full product; the adjacency path uses only the point test
# `isMember`, so `edges` of a predicate-restricted product never enumerates.
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
    imap0
    range
    length
    listToAttrs
    ;
  inherit (builtins) toJSON fromJSON;

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
  # factor's own `nodes` order preserved. Forces every factor node list — the en-masse operation, the
  # documented exception to the Kahn 1974 demand discipline.
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

  # First-seen deduplication by cellId, applying the codec ONCE per element. `listToAttrs` keeps the
  # FIRST binding for a repeated name, so `firstAt` maps each key to the index of its first
  # occurrence and "x is the first of its key" becomes an index comparison instead of a rescan of
  # everything already accepted. Given order is preserved by construction — survivors are selected
  # from the index range in order (B5 discipline, no silent reorder) — and `range 0 (-1)` is [ ], so
  # the empty list is total rather than accidental.
  #
  # Specialized on `def` rather than parametric in a `keyFn`: an index needs its keys to be attribute
  # names, and applying `fullCellId def` here makes that string codomain a type fact of the codec
  # (`toJSON` of the key tuple) instead of a caller precondition whose violation is a bare
  # `listToAttrs` type abort.
  firstSeenById =
    def: xs:
    let
      keys = map (fullCellId def) xs;
      firstAt = listToAttrs (
        imap0 (i: k: {
          name = k;
          value = i;
        }) keys
      );
    in
    map (i: elemAt xs i) (filter (i: firstAt.${elemAt keys i} == i) (range 0 (length xs - 1)));

  relationsCoverAll =
    def: restriction:
    let
      covered = unique (concatMap (r: r.dims) restriction.relations);
    in
    restriction.relations != [ ] && all (d: elem d covered) def.dims;

  # Strategy 2 — relational join. Seed with the first declared relation's pairs, extend each partial
  # tuple across the remaining relations in declared order (shared dims must agree). Deterministic and
  # never materializes the full product.
  #
  # The extension is an EQUIJOIN and is evaluated by index, not by nested scan: each relation step
  # groups its probe side (`r.pairs`) once on the shared-dim key and every partial does one lookup.
  # The probe key is the cellId's own codec (`keyTuple` + toJSON), so a join probe and a cellId cannot
  # disagree about what a coordinate is.
  #
  # The shared-dim set is computed PER PARTIAL, exactly as the scan form computed it. Hoisting it to
  # the relation's DECLARED dims is shorter but equals the scan form only when every pair's attribute
  # set is exactly `r.dims` — a precondition no caller is bound by, and the seed partials carry only
  # the first relation's dims, so the hoisted probe reads an attribute the partial does not have.
  # Indexing per distinct partial SHAPE keeps the scan form's own test and needs no precondition; a
  # homogeneous accumulator has one shape and therefore one index.
  #
  # Order is the scan form's: the outer `concatMap` still runs over `acc` in order, and
  # `builtins.groupBy` preserves `r.pairs` order within a bucket. Disjoint dims (`shared == [ ]`) key
  # every pair and every partial alike, giving one bucket and the cross product — the same expression
  # rather than a special case.
  joinEnumerate =
    def: restriction:
    let
      relations = restriction.relations;
      seed = (elemAt relations 0).pairs;
      sharedOf = r: partial: filter (d: builtins.hasAttr d partial) r.dims;
      keyOn = dims: coords: toJSON (keyTuple def dims coords);
      extend =
        acc: r:
        let
          byShape = builtins.groupBy (partial: toJSON (sharedOf r partial)) acc;
          indexFor = builtins.mapAttrs (
            shapeKey: _: builtins.groupBy (keyOn (fromJSON shapeKey)) r.pairs
          ) byShape;
        in
        concatMap (
          partial:
          let
            shared = sharedOf r partial;
          in
          map (pair: partial // pair) (indexFor.${toJSON shared}.${keyOn shared partial} or [ ])
        ) acc;
      joined = foldl' extend seed (tail relations);
    in
    firstSeenById def (filter restriction.predicate joined);

  enumerateMembers =
    def: restriction:
    if restriction == null then
      enumerateFull def
    else if restriction.cells != null then
      # Strategy 1 — explicit cells, first-seen deduplicated by cellId, given order preserved
      # (no silent reorder, B5 discipline), then filtered by clauses (2) and (3).
      filter (isMember def restriction) (firstSeenById def restriction.cells)
    else if relationsCoverAll def restriction then
      joinEnumerate def restriction
    else
      # Strategy 3 — filter the full-product enumeration. Documented O(Π |V_i|) cost.
      filter (isMember def restriction) (enumerateFull def);

  # The member set is a property of (def, restriction) ALONE: `enumerateFull`'s signature is `def:`
  # and `enumerateMembers`'s is `def: restriction:`, so neither takes a `base` and neither can read
  # one. Naming the set once here is what lets every view over the same (def, restriction) — a whole
  # product and all of its slices — share ONE enumeration instead of re-deriving it per view. It is
  # not a cache beside a query: there is a single derivation, views take it as a required argument,
  # and no configuration selects a second one.
  #
  # `fibersByDim` answers a slice by lookup instead of by filter. A slice fixes one coordinate per
  # base dim, so the members it speaks about are exactly the preimage of the projection π_d over that
  # coordinate — the fiber. Each entry is a thunk, so a dim nobody slices on is never grouped and a
  # product that is only enumerated pays nothing for it. The bucket key is the cellId's codec, whose
  # declared injectivity on each factor's id domain is what makes a bucket exactly the preimage
  # rather than a subset of it.
  enumerationOf =
    def: restriction:
    let
      members = if restriction == null then enumerateFull def else enumerateMembers def restriction;
    in
    {
      inherit members;
      fibersByDim = listToAttrs (
        map (d: {
          name = d;
          value = builtins.groupBy (c: toJSON ((def.factorsByDim.${d}).key c.${d})) members;
        }) def.dims
      );
    };
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
    enumerationOf
    firstSeenById
    ;
}
