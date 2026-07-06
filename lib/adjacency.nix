# gen-product — lib/adjacency.nix : per-kind product adjacency, applied coordinatewise to directed
# factor edges.
#
# THEORY. Hammack, Imrich & Klavžar, *Handbook of Product Graphs* (2nd ed., CRC Press, 2011), Part I:
# the four standard graph products. Writing u_i ~ v_i for a directed factor edge u_i -> v_i in
# dimension d_i, the cell u = { d_i = u_i } has an edge to v = { d_i = v_i } iff:
#
#   cartesian      exactly one dimension has u_i ~ v_i; all others equal            (G □ H)
#   tensor         every dimension has u_i ~ v_i                                    (G × H)
#   strong         every dimension has u_i = v_i OR u_i ~ v_i, at least one ~       (G ⊠ H)
#   lexicographic  at the first (declared-order) differing dim: u_i ~ v_i;          (G ∘ H)
#                  earlier dims equal; later dims unconstrained
#
# The Handbook states these for finite simple undirected graphs; gen-product applies the coordinatewise
# rule to directed adjacency (the standard digraph generalization) and degenerates to the textbook
# objects on symmetric edge relations. Costs are inherent to the product, not the implementation:
# cartesian O(Σ outdeg_i); tensor O(Π outdeg_i); strong O(Π (outdeg_i + 1)); lexicographic at dim k
# forces Π_{i>k} |V_i| — the one documented exception to laziness (trailing factor node lists).
{ prelude }:
let
  inherit (prelude)
    concatMap
    map
    range
    elemAt
    foldl'
    filter
    any
    length
    imap0
    ;

  # cartesian product of a list of lists: [[a]] -> [[a]]. First list varies slowest, last fastest —
  # the same row-major discipline as cell enumeration (pinned order, law P14).
  cartProd = lists: foldl' (acc: xs: concatMap (a: map (x: a ++ [ x ]) xs) acc) [ [ ] ] lists;

  replaceAt =
    i: w: xs:
    imap0 (idx: v: if idx == i then w else v) xs;

  # targetsFor : kind -> fullKeys(list of factor node ids, declared order) -> factorsList -> [target
  # key-vectors]. Never scans a factor's `nodes` (Kahn 1974 demand discipline, law P10) EXCEPT the
  # lexicographic trailing-dim fan-out, which forces trailing node lists by construction.
  targetsFor =
    kind: fullKeys: factorsList:
    let
      n = length factorsList;
      idxs = range 0 (n - 1);
      neighbors = i: (elemAt factorsList i).graph.edges (elemAt fullKeys i);
    in
    if kind == "cartesian" then
      concatMap (i: map (w: replaceAt i w fullKeys) (neighbors i)) idxs
    else if kind == "tensor" then
      # Every dimension advances. At arity 0 the empty product is the edgeless unit K1 (law P9 refuses
      # a tensor self-loop here — the tensor unit is the LOOPED one-vertex graph, not K1).
      (if n == 0 then [ ] else cartProd (map neighbors idxs))
    else if kind == "strong" then
      # Each dimension stays (tag adv=false) or advances via a factor edge (adv=true, possibly a
      # self-loop); keep tuples with ≥1 advance. Testing "advanced" structurally — not by target
      # identity — is what preserves a genuine strong self-loop at a looped coordinate.
      let
        opts = map (
          i:
          [
            {
              key = elemAt fullKeys i;
              adv = false;
            }
          ]
          ++ map (w: {
            key = w;
            adv = true;
          }) (neighbors i)
        ) idxs;
        combos = cartProd opts;
        advanced = filter (combo: any (c: c.adv) combo) combos;
      in
      map (combo: map (c: c.key) combo) advanced
    else if kind == "lexicographic" then
      concatMap (
        j:
        let
          earlier = map (i: elemAt fullKeys i) (range 0 (j - 1));
          laterIdxs = range (j + 1) (n - 1);
          laterCombos = cartProd (map (i: (elemAt factorsList i).graph.nodes) laterIdxs);
        in
        concatMap (w: map (laterVec: earlier ++ [ w ] ++ laterVec) laterCombos) (neighbors j)
      ) idxs
    else
      throw "gen-product: unknown-kind '${kind}'";
in
{
  inherit targetsFor cartProd;
}
