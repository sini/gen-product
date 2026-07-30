# gen-product — lib/product.nix : the product constructors.
#
# `productN kind factors` builds a product accessor-graph over an ORDERED list of factor specs; the
# order is the declared factor order (pins enumeration order for all kinds; carries adjacency meaning
# only for lexicographic). The four binary sugars specialize to the textbook G □ H / G × H / G ⊠ H /
# G ∘ H (Handbook of Product Graphs, Part I). Degenerate arities: `productN kind [ ]` = K1 (one cell,
# no edges — a unit for cartesian/strong/lexicographic, but NOT for tensor: the Handbook's direct-
# product unit is the looped one-vertex graph); `productN kind [ f ]` is isomorphic to `f.graph` under
# the coordinate codec.
{
  prelude,
  factor,
  view,
}:
let
  inherit (prelude)
    map
    elem
    filter
    length
    listToAttrs
    head
    tail
    ;
  inherit (factor) normalizeFactors;
  inherit (view) mkView enumerationOf;

  validKinds = [
    "cartesian"
    "tensor"
    "strong"
    "lexicographic"
  ];

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

  productN =
    kind: rawFactors:
    if !(elem kind validKinds) then
      throw "gen-product: unknown-kind '${kind}' — expected one of cartesian | tensor | strong | lexicographic"
    else
      let
        factors = normalizeFactors rawFactors;
        dims = map (f: f.dim) factors;
        dup = firstDuplicate dims;
        factorsByDim = listToAttrs (
          map (f: {
            name = f.dim;
            value = f;
          }) factors
        );
        def = {
          inherit kind dims factorsByDim;
          factorsList = factors;
        };
      in
      if dup != null then
        throw "gen-product: duplicate-dim '${dup}' — two factors share a dimension name"
      else
        # A fresh `def` and no restriction — there is nothing to share from, so the constructed
        # product derives its own member set.
        mkView {
          inherit def;
          enumeration = enumerationOf def null;
        };

  cartesian =
    f1: f2:
    productN "cartesian" [
      f1
      f2
    ];
  tensor =
    f1: f2:
    productN "tensor" [
      f1
      f2
    ];
  strong =
    f1: f2:
    productN "strong" [
      f1
      f2
    ];
  lexicographic =
    f1: f2:
    productN "lexicographic" [
      f1
      f2
    ];
in
{
  inherit
    productN
    cartesian
    tensor
    strong
    lexicographic
    ;
}
