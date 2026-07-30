# gen-product — lib/view.nix : the product accessor-graph (`<pgraph>`) builder.
#
# A product IS an accessor-graph — every gen-graph query { edges, parent, nodes, nodeData } works on
# it unchanged — extended with a `product` metadata field that gen-product's own operations read.
# One builder, `mkView`, produces the full product, its slices, and its restrictions uniformly: a view
# is characterized by (def, base, restriction) where
#   def         = { kind; dims; factorsByDim; factorsList; } — the immutable full product definition;
#   base        = fixed coordinates (entries) over a subset of dims — nonempty on a slice;
#   restriction = a membership record | null.
# The free dimensions are def.dims minus base; a slice speaks FREE coordinates only, and induced edges
# are computed by reconstructing full coordinates (base ∪ free), taking the full product's adjacency,
# and filtering back to the slice — the mathematically induced sub-product.
#
# THEORY. Kahn 1974 (demand-driven structure, inherited via gen-graph's accessor convention): every
# accessor forces only what a traversal visits. cellId codec = builtins.toJSON of the ordered factor
# node ids — canonical, injective on each factor's id domain (the codec precondition), and free of
# separator-injection hazards.
{
  prelude,
  adjacency,
  membership,
}:
let
  inherit (prelude)
    map
    filter
    elem
    elemAt
    length
    foldl'
    concatMap
    listToAttrs
    attrNames
    imap0
    all
    unique
    range
    head
    tail
    concatStringsSep
    ;
  inherit (builtins)
    toJSON
    fromJSON
    tryEval
    isString
    ;
  inherit (adjacency) targetsFor;
  inherit (membership) isMember enumerationOf;

  # Render a coordinate entry for an error message — its `.name` if present, else its JSON key.
  # display only; never part of the data vocabulary.
  renderEntry =
    f: entry:
    let
      t = tryEval (if entry ? name then entry.name else toJSON (f.key entry));
    in
    if t.success then (if isString t.value then t.value else toJSON t.value) else "<malformed-entry>";

  # Pointwise not-a-node detection (reconciled with Kahn 1974 demand-driven laziness): a coordinate is not-a-node
  # iff `key entry` throws, `entryOf (key entry)` throws, or the round-trip `key (entryOf (key entry))`
  # mismatches. Never scans a factor's `nodes` list. Vacuous on the identity codec (round-trip always
  # holds), where non-nodes surface downstream instead.
  notANode =
    f: entry:
    let
      k = tryEval (f.key entry);
    in
    if !k.success then
      true
    else
      let
        e = tryEval (f.entryOf k.value);
      in
      if !e.success then
        true
      else
        let
          rt = tryEval (f.key e.value);
        in
        if !rt.success then true else rt.value != k.value;

  # `enumeration` is REQUIRED and never defaulted. The member set does not depend on `base`, so every
  # view over one (def, restriction) shares it — but a defaulted `enumeration ? enumerationOf def
  # restriction` would let a constructor that already holds the value silently re-derive it, which is
  # the whole cost this argument exists to remove. Requiring it makes "which member set is this
  # view's" a question every constructor answers rather than one it can forget, and a constructor
  # added later cannot evaluate without answering it.
  mkView =
    {
      def,
      base ? { },
      restriction ? null,
      enumeration,
    }:
    let
      allDims = def.dims;
      baseDims = attrNames base;
      freeDims = filter (d: !(builtins.hasAttr d base)) allDims;
      freeFactors = listToAttrs (
        map (d: {
          name = d;
          value = def.factorsByDim.${d};
        }) freeDims
      );

      keyOf = d: entry: (def.factorsByDim.${d}).key entry;
      baseKeyAt = d: keyOf d base.${d};

      # ── free-coordinate codec ──
      cellOfFree = coords: toJSON (map (d: keyOf d coords.${d}) freeDims);
      coordsOfFree =
        cellId:
        let
          keys = fromJSON cellId;
        in
        listToAttrs (
          imap0 (i: d: {
            name = d;
            value = (def.factorsByDim.${d}).entryOf (elemAt keys i);
          }) freeDims
        );

      # Reconstruct the full key vector (over allDims) from a free cellId, threading `base`.
      fullKeysOf =
        freeCellId:
        let
          fk = fromJSON freeCellId;
          byDim = listToAttrs (
            imap0 (i: d: {
              name = d;
              value = elemAt fk i;
            }) freeDims
          );
        in
        map (d: if builtins.hasAttr d base then baseKeyAt d else byDim.${d}) allDims;

      dimPos = listToAttrs (
        imap0 (i: d: {
          name = d;
          value = i;
        }) allDims
      );

      fullCoordsOfKeys =
        fullKeys:
        listToAttrs (
          imap0 (i: d: {
            name = d;
            value = (def.factorsByDim.${d}).entryOf (elemAt fullKeys i);
          }) allDims
        );

      freeCellIdOfKeys = fullKeys: toJSON (map (d: elemAt fullKeys dimPos.${d}) freeDims);

      # ── induced edges ──
      edges =
        freeCellId:
        let
          fullKeys = fullKeysOf freeCellId;
          rawTargets = targetsFor def.kind fullKeys def.factorsList;
          keep =
            t:
            all (d: elemAt t dimPos.${d} == baseKeyAt d) baseDims
            && (restriction == null || isMember def restriction (fullCoordsOfKeys t));
        in
        unique (map freeCellIdOfKeys (filter keep rawTargets));

      nodeData = freeCellId: coordsOfFree freeCellId;
      parent = _cellId: null;

      # ── enumeration ──
      # For a slice we keep only the shared members that extend `base`, then project to free coords;
      # the underlying enumeration already dedups (strategies 1/2) and yields distinct full coords, so
      # no further dedup is required.
      #
      # A slice is a FIBER of a projection, so the first base dim is answered by one bucket lookup
      # rather than by scanning the member set, and only the remaining base dims stay a filter — over
      # that bucket, not over everything. `fibersByDim`'s domain is `def.dims`, and every base dim was
      # validated FREE before it entered `base`, so the dim lookup is total; a base coordinate with no
      # member has no bucket and `or [ ]` yields the empty slice, which is what filtering would have
      # returned. `builtins.groupBy` preserves member-set order within a bucket.
      cellsList =
        let
          d0 = head baseDims;
          narrowed =
            if baseDims == [ ] then
              enumeration.members
            else
              enumeration.fibersByDim.${d0}.${toJSON (baseKeyAt d0)} or [ ];
          rest = if baseDims == [ ] then [ ] else tail baseDims;
          extending = filter (c: all (d: keyOf d c.${d} == baseKeyAt d) rest) narrowed;
        in
        map (
          c:
          listToAttrs (
            map (d: {
              name = d;
              value = c.${d};
            }) freeDims
          )
        ) extending;

      nodes = map cellOfFree cellsList;

      # ── validated addressing (public `cell`) ──
      declaredMsg = "declared (free) dims: ${concatStringsSep ", " freeDims}";
      cellValidated =
        coords:
        let
          ks = attrNames coords;
          unknown = filter (d: !(elem d freeDims)) ks;
          missing = filter (d: !(builtins.hasAttr d coords)) freeDims;
          badNode = filter (d: notANode def.factorsByDim.${d} coords.${d}) freeDims;
        in
        if unknown != [ ] then
          let
            d = head unknown;
            fixedNote = if builtins.hasAttr d base then " (dimension '${d}' is fixed in this slice)" else "";
          in
          throw "gen-product: unknown-dim '${d}'${fixedNote} — ${declaredMsg}"
        else if missing != [ ] then
          throw "gen-product: missing-dim — cell requires coordinates for: ${concatStringsSep ", " missing}"
        else if badNode != [ ] then
          let
            d = head badNode;
          in
          throw "gen-product: not-a-node in dim '${d}' — ${renderEntry def.factorsByDim.${d} coords.${d}}"
        else if restriction != null && !(isMember def restriction (base // coords)) then
          throw "gen-product: not-a-member — ${showCoords (base // coords)} is outside this restricted product"
        else
          cellOfFree coords;

      showCoords =
        coords:
        concatStringsSep ", " (
          map (d: "${d}=${renderEntry def.factorsByDim.${d} coords.${d}}") (attrNames coords)
        );

      product = {
        inherit (def) kind;
        dims = freeDims;
        factors = freeFactors;
        cellOf = cellOfFree;
        coordsOf = coordsOfFree;
        inherit base;
        inherit restriction;
      };
    in
    {
      inherit
        edges
        parent
        nodes
        nodeData
        product
        ;
      __def = def;
      __base = base;
      __restriction = restriction;
      __enumeration = enumeration;
      __cell = cellValidated;
      __cells = cellsList;
      __freeDims = freeDims;
      __showCoords = showCoords;
      __renderEntry = renderEntry;
    };

  # Slice a pgraph: fix a subset of its FREE dimensions. Validates that each named dim is free
  # (naming a fixed dim is an unknown-dim error); base accumulates so slices compose.
  sliceView =
    pg: partialCoords:
    let
      freeDims = pg.__freeDims;
      unknown = filter (d: !(elem d freeDims)) (attrNames partialCoords);
    in
    if unknown != [ ] then
      let
        d = head unknown;
        fixedNote =
          if builtins.hasAttr d pg.__base then " (dimension '${d}' is fixed in this slice)" else "";
      in
      throw "gen-product: unknown-dim '${d}'${fixedNote} — declared (free) dims: ${concatStringsSep ", " freeDims}"
    else
      mkView {
        def = pg.__def;
        base = pg.__base // partialCoords;
        restriction = pg.__restriction;
        # `def` and `restriction` are carried through UNCHANGED, which is exactly the hypothesis
        # under which the parent's member set is this slice's — satisfied by the expression itself
        # rather than by a claim about it. Slicing is the only constructor that may thread it.
        enumeration = pg.__enumeration;
      };
in
{
  inherit
    mkView
    sliceView
    notANode
    enumerationOf
    ;
}
