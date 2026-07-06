# gen-product — lib/quotient.nix : graph quotient by an equivalence.
#
# A general accessor-graph operation (any graph, product or not) — placed here because class-share is
# its motivating instantiation: `quotient hostsGraph { classOf = h: h.class; }` is the hosts-by-class
# collapse as a one-liner. `classOf` receives the node's data (the registry entry, per the identity
# law) and returns a class token (itself an entry); `key` maps the token to a quotient node id.
#
# THEORY. Mokhov 2017, *Algebraic Graphs with Class* (§4): `quotient` generalizes the condensation
# quotient. The quotient map is by construction a STRICT graph homomorphism (loops allowed) — every
# input edge u -> v yields a quotient edge [u] -> [v] (soundness), and every quotient edge is witnessed
# by a member edge (completeness), law P12. Quotient is a GLOBAL operation: it forces the input's node
# enumeration (law P10), building the member index once.
{ prelude }:
let
  inherit (prelude)
    map
    filter
    elem
    concatMap
    foldl'
    unique
    attrNames
    listToAttrs
    ;

  quotient =
    graph:
    {
      classOf,
      key ? (t: t.id_hash),
      classData ? (
        t: members: {
          class = t;
          inherit members;
        }
      ),
      keepSelfLoops ? true,
    }:
    let
      inputNodes = graph.nodes;
      classKeyOf = id: key (classOf (graph.nodeData id));

      # First-seen class order over the input node enumeration (pinned; no silent reorder).
      classKeys = foldl' (
        acc: id:
        let
          k = classKeyOf id;
        in
        if elem k acc then acc else acc ++ [ k ]
      ) [ ] inputNodes;

      # Member index (built once): class key -> member ids, in input node order.
      membersByClass = listToAttrs (
        map (k: {
          name = k;
          value = filter (id: classKeyOf id == k) inputNodes;
        }) classKeys
      );

      # First-seen token per class (for classData).
      tokenByClass = listToAttrs (
        map (k: {
          name = k;
          value = classOf (graph.nodeData (builtins.head membersByClass.${k}));
        }) classKeys
      );

      edges =
        classKey:
        let
          members = membersByClass.${classKey} or [ ];
          targets = unique (concatMap (m: map classKeyOf (graph.edges m)) members);
        in
        if keepSelfLoops then targets else filter (t: t != classKey) targets;

      nodeData = classKey: classData tokenByClass.${classKey} membersByClass.${classKey};
    in
    {
      nodes = classKeys;
      inherit edges nodeData;
      parent = _classKey: null;
    };
in
{
  inherit quotient;
}
