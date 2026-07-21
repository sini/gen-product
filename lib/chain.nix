# gen-product — lib/chain.nix : the containment chain and its linearizations.
#
# For a cell c with dimension set D, the slices containing c are in bijection with subsets S ⊆ D (fix
# c's coordinates on S, leave D \ S free); S ⊆ S' means S' is MORE specific. `containmentChain` returns
# all 2^|D| subsets — ∅ (whole product, least specific) to D (the cell, most specific) — as a LINEAR
# EXTENSION of the inclusion order, incomparable subsets ordered by a declared linearization.
# It never forces a slice's structure — the chain is metadata; slices stay lazy (Kahn 1974 demand
# discipline).
#
# Two canonical linearizations, both provably total (they reject degenerate inputs rather than
# silently tie-break):
#   linearizeByDimOrder dims  — key(S) = ( |S|, sortDescending (map rank S) ), count-major. THE DEN
#                               FLEET DEFAULT: every single-dim slice precedes any pairwise slice, so
#                               [ env host user ] yields default < env < host < user < … < cell.
#   linearizations.byRank ranks — key(S) = sortDescending (map rank S), top-rank interleave: the
#                               two-dim {env,host} precedes the single-dim {user}.
# A raw comparator (a: b: bool, "a strictly less specific than b") is also accepted, validated against
# all comparable subset pairs.
{
  prelude,
  view,
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
    sort
    listToAttrs
    head
    tail
    imap0
    concatStringsSep
    unique
    ;
  inherit (builtins) isFunction;

  # Powerset, deterministic order (not load-bearing — the linearization re-sorts).
  subsets =
    xs:
    if xs == [ ] then
      [ [ ] ]
    else
      let
        rest = subsets (tail xs);
        h = head xs;
      in
      rest ++ map (s: [ h ] ++ s) rest;

  # Lexicographic strict-less on integer lists: [] is smallest; a proper prefix is smaller.
  lexLt =
    a: b:
    if a == [ ] then
      b != [ ]
    else if b == [ ] then
      false
    else
      let
        x = head a;
        y = head b;
      in
      if x < y then
        true
      else if x > y then
        false
      else
        lexLt (tail a) (tail b);

  sortDesc = xs: sort (a: b: a > b) xs;

  indexOf = xs: v: head (filter (i: elemAt xs i == v) (imap0 (i: _: i) xs));

  properSubset = a: b: a != b && builtins.all (x: elem x b) a;

  linearizeByDimOrder = dims: {
    _type = "gen-product/linearization";
    kind = "dimOrder";
    inherit dims;
  };
  byRank = ranks: {
    _type = "gen-product/linearization";
    kind = "byRank";
    inherit ranks;
  };
  linearizations = {
    inherit byRank;
  };

  # ── validations (definition-time) ──
  validateDimOrder =
    D: dims:
    let
      uncovered = filter (d: !(elem d dims)) D;
      productNames = filter (d: elem d D) dims;
      dup = firstDuplicate productNames;
    in
    if uncovered != [ ] then
      throw "gen-product: missing-dim-order — linearizeByDimOrder omits: ${concatStringsSep ", " uncovered}"
    else if dup != null then
      throw "gen-product: duplicate-dim-order — dimension '${dup}' named more than once"
    else
      null;

  validateByRank =
    D: ranks:
    let
      uncovered = filter (d: !(builtins.hasAttr d ranks)) D;
      rankOf = d: ranks.${d};
      collide = firstRankCollision D rankOf;
    in
    if uncovered != [ ] then
      throw "gen-product: missing-rank — byRank table lacks ranks for: ${concatStringsSep ", " uncovered}"
    else if collide != null then
      throw "gen-product: duplicate-rank — dims ${concatStringsSep ", " collide.dims} share rank ${toString collide.rank}"
    else
      null;

  firstDuplicate =
    xs:
    let
      go =
        seen: rest:
        if rest == [ ] then
          null
        else if elem (head rest) seen then
          head rest
        else
          go (seen ++ [ (head rest) ]) (tail rest);
    in
    go [ ] xs;

  firstRankCollision =
    D: rankOf:
    let
      go =
        rest:
        if rest == [ ] then
          null
        else
          let
            d = head rest;
            r = rankOf d;
            sharers = filter (e: rankOf e == r) D;
          in
          if length sharers > 1 then
            {
              dims = sharers;
              rank = r;
            }
          else
            go (tail rest);
    in
    go D;

  containmentChain =
    pg: coords: lin:
    let
      _validated = pg.__cell coords; # reuse cell validation (unknown/missing/not-a-node/not-a-member)
      D = pg.product.dims; # free dims of pg, declared order
      subs = subsets D;
      projectCoords =
        S:
        listToAttrs (
          map (d: {
            name = d;
            value = coords.${d};
          }) S
        );
      mkEntry = S: {
        subset = S;
        fixed = projectCoords S;
        free = filter (d: !(elem d S)) D;
      };

      sortedSubs =
        if isFunction lin then
          let
            entries = map mkEntry subs;
            entryOfSubset = S: head (filter (e: e.subset == S) entries);
            pairs = concatMap (
              a: concatMap (b: if properSubset a b then [ { inherit a b; } ] else [ ]) subs
            ) subs;
            bad = if length D > 8 then [ ] else filter (p: lin (entryOfSubset p.b) (entryOfSubset p.a)) pairs;
          in
          if bad != [ ] then
            throw "gen-product: bad-linearization — comparator orders ${showSubset (head bad).b} before its subset ${showSubset (head bad).a}"
          else
            map (e: e.subset) (sort (a: b: lin a b) entries)
        else if lin.kind == "dimOrder" then
          let
            rank = d: indexOf lin.dims d;
            key = S: [ (length S) ] ++ sortDesc (map rank S);
          in
          builtins.seq (validateDimOrder D lin.dims) (sort (a: b: lexLt (key a) (key b)) subs)
        else
          let
            key = S: sortDesc (map (d: lin.ranks.${d}) S);
          in
          builtins.seq (validateByRank D lin.ranks) (sort (a: b: lexLt (key a) (key b)) subs);
    in
    # Force coords validation eagerly (unknown/missing/not-a-node/not-a-member) — the chain records
    # themselves never force it, so `seq` makes the definition-time errors fire. Pointwise validation
    # never scans a factor's `nodes` (Kahn 1974 demand discipline), so this stays green under the
    # throwing-nodes fixture.
    builtins.seq _validated (
      imap0 (rank: S: {
        fixed = projectCoords S;
        free = filter (d: !(elem d S)) D;
        slice = view.sliceView pg (projectCoords S);
        inherit rank;
      }) sortedSubs
    );

  showSubset = dims: "{" + concatStringsSep "," dims + "}";

  # latticeGraph (feature #2) — the boolean lattice 2^D exposed as its COVERING relation (Hasse diagram):
  # the transitive reduction of subset inclusion, S ⋖ S∪{d} for each d ∈ D\S (Davey & Priestley,
  # *Introduction to Lattices and Order*, 2nd ed., §1.2/2.5 — covers = adds one atom; the boolean lattice
  # is the atomistic 2^D). Returned in den's node.query-traversable flat labeled edge shape
  # `[{ kind; from; to }]`: `kind` is the added dimension (the edge label), `from`/`to` are `showSubset`
  # subset ids, one edge per added dimension. STRUCTURE ONLY — no linearization is baked in (the
  # count-major order is a separate ordering discipline over the queried slice set, not a traversal).
  # Pure metadata over the dimension set; like the chain it never forces a slice (Kahn 1974). S∪{d} is
  # renormalized to D's declared order (`canonicalize`) so `to` matches the `from`-side node id exactly.
  latticeGraph =
    D:
    let
      subs = subsets D; # each already in D-declared order (the head-prepend recursion preserves it)
      canonicalize = S: filter (d: elem d S) D; # reorder S∪{d} to the same keying `subs` uses
      edges = concatMap (
        S:
        map (d: {
          kind = d;
          from = showSubset S;
          to = showSubset (canonicalize (S ++ [ d ]));
        }) (filter (d: !(elem d S)) D)
      ) subs;
    in
    {
      nodes = map showSubset subs;
      inherit edges;
    };
in
{
  inherit
    containmentChain
    latticeGraph
    linearizeByDimOrder
    linearizations
    ;
}
