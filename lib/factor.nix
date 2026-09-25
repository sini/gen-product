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
  inherit (prelude)
    imap0
    map
    elem
    head
    tail
    ;
  inherit (builtins) toString;

  # A value is a factor spec iff it carries a `graph` field; a bare accessor-graph never does
  # (it carries edges/parent/nodes/nodeData). The discriminator is total on both shapes.
  isFactorSpec = spec: spec ? graph;

  # Callable is a function, or a set whose `__functor` is one: `f ? __functor` alone admits
  # `{ __functor = 1; }`, which aborts when applied. Copied, not imported (gen-prelude is this
  # library's only dependency), from gen-graph's `callable` (`lib/key.nix`).
  callable =
    f:
    builtins.isFunction f || (builtins.isAttrs f && f ? __functor && builtins.isFunction f.__functor);

  # THE FACTOR-SPEC DOORS (den-hoag-i25f; ADR-0025 item 1). A codec failure gen-product can decide
  # is refused by name; one it cannot is the caller's contract (README, "Factor-spec contract").
  #  - The default `key` is gen-product's own, so its partiality is a `throw`, which `notANode`'s
  #    `tryEval` observes: `cell` then refuses `not-a-node`. Anywhere else it surfaces as itself.
  #  - `key` / `entryOf` must be callable, and `entryOf` must not name a pattern formal: it takes a
  #    node id, a scalar (gen-graph's `nodeKey` refuses sets), and a pattern formal accepts only a
  #    set. A lambda with no named formal (`{ ... }:`) and a functor are indistinguishable from
  #    `x: …` here, so they are residue, pinned by falsifiers in `ci/tests-error.nix`.
  # These two are thunks inside the normalized factor; `checkFactors` forces them at construction,
  # outside `notANode`'s `tryEval`, which would otherwise swallow the name.
  normalizeFactor =
    idx: spec:
    if isFactorSpec spec then
      let
        where = "dim '${toString (spec.dim or idx)}'";
        fn =
          name: f:
          if callable f then
            f
          else
            throw "gen-product: malformed-factor — ${where}: `${name}` is a ${builtins.typeOf f}, not a function";
        entryOf = fn "entryOf" (spec.entryOf or spec.graph.nodeData);
      in
      {
        inherit (spec) dim graph;
        key = fn "key" (
          spec.key or (
            entry:
            if builtins.isAttrs entry && entry ? id_hash then
              entry.id_hash
            else
              throw "gen-product: not-a-node in ${where} — the default key reads `id_hash`, and the coordinate is ${
                if builtins.isAttrs entry then "an attrset without it" else "a ${builtins.typeOf entry}"
              }"
          )
        );
        entryOf =
          if builtins.isFunction entryOf && builtins.functionArgs entryOf != { } then
            throw "gen-product: malformed-factor — ${where}: `entryOf` takes a node id (a scalar), which a pattern formal cannot accept"
          else
            entryOf;
      }
    else
      {
        dim = toString idx;
        graph = spec;
        key = id: id;
        entryOf = id: id;
      };

  normalizeFactors = factors: imap0 normalizeFactor factors;

  # Force each normalized factor's `key` and `entryOf` to WHNF (the shape doors above) and return
  # `k`. Never forces `nodes`, so construction stays lazy in the factor graphs.
  checkFactors =
    factors: k:
    builtins.seq (builtins.foldl' (a: f: builtins.seq f.key (builtins.seq f.entryOf a)) null factors) k;

  # The first element of `xs` that repeats an earlier one (structural ==), else null. The ONE
  # definition behind both dimension-name refusals: `productN`'s duplicate-dim and
  # `linearizeByDimOrder`'s duplicate-dim-order. gen-prelude exports no equivalent.
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
in
{
  inherit
    normalizeFactor
    normalizeFactors
    checkFactors
    firstDuplicate
    ;
}
