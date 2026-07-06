# golden-classics (laws P1–P4): the undirected textbook classics pinned on symmetric-digraph K2 pairs
# — K2 □ K2 = C4, K2 × K2 = 2K2, K2 ⊠ K2 = K4, K2 ∘ K2 = K4 (Handbook of Product Graphs). Materialized
# edge maps, compared to explicitly hand-listed expected maps.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx) idFactor;
  gp = genProduct;

  factors = [
    (idFactor "x" fx.k2)
    (idFactor "y" fx.k2)
  ];
  mk = kind: gp.productN kind factors;

  c =
    p: x: y:
    p.product.cellOf { inherit x y; };
  edgeMap =
    p:
    lib.listToAttrs (
      map (coord: {
        name = p.product.cellOf coord;
        value = lib.sort lib.lessThan (p.edges (p.product.cellOf coord));
      }) (gp.cells p)
    );
  neigh = p: pairs: lib.sort lib.lessThan (map ({ x, y }: c p x y) pairs);

  cart = mk "cartesian";
  tens = mk "tensor";
  strong = mk "strong";
  lex = mk "lexicographic";
in
{
  flake.tests.golden-classics = {
    # □ = C4 : each vertex adjacent to the two that differ in exactly one coordinate.
    test-cartesian-is-C4 = {
      expr = edgeMap cart;
      expected = {
        ${c cart "u" "u"} = neigh cart [
          {
            x = "v";
            y = "u";
          }
          {
            x = "u";
            y = "v";
          }
        ];
        ${c cart "u" "v"} = neigh cart [
          {
            x = "v";
            y = "v";
          }
          {
            x = "u";
            y = "u";
          }
        ];
        ${c cart "v" "u"} = neigh cart [
          {
            x = "u";
            y = "u";
          }
          {
            x = "v";
            y = "v";
          }
        ];
        ${c cart "v" "v"} = neigh cart [
          {
            x = "u";
            y = "v";
          }
          {
            x = "v";
            y = "u";
          }
        ];
      };
    };
    # × = 2K2 : each vertex adjacent only to its full-complement (both coordinates flip).
    test-tensor-is-2K2 = {
      expr = edgeMap tens;
      expected = {
        ${c tens "u" "u"} = neigh tens [
          {
            x = "v";
            y = "v";
          }
        ];
        ${c tens "u" "v"} = neigh tens [
          {
            x = "v";
            y = "u";
          }
        ];
        ${c tens "v" "u"} = neigh tens [
          {
            x = "u";
            y = "v";
          }
        ];
        ${c tens "v" "v"} = neigh tens [
          {
            x = "u";
            y = "u";
          }
        ];
      };
    };
    # ⊠ = K4 : every vertex adjacent to all three others.
    test-strong-is-K4 = {
      expr = edgeMap strong;
      expected = {
        ${c strong "u" "u"} = neigh strong [
          {
            x = "v";
            y = "u";
          }
          {
            x = "u";
            y = "v";
          }
          {
            x = "v";
            y = "v";
          }
        ];
        ${c strong "u" "v"} = neigh strong [
          {
            x = "v";
            y = "v";
          }
          {
            x = "u";
            y = "u";
          }
          {
            x = "v";
            y = "u";
          }
        ];
        ${c strong "v" "u"} = neigh strong [
          {
            x = "u";
            y = "u";
          }
          {
            x = "v";
            y = "v";
          }
          {
            x = "u";
            y = "v";
          }
        ];
        ${c strong "v" "v"} = neigh strong [
          {
            x = "u";
            y = "v";
          }
          {
            x = "v";
            y = "u";
          }
          {
            x = "u";
            y = "u";
          }
        ];
      };
    };
    # ∘ = K4 : x-edge reaches both trailing values; x-equal + y-edge reaches the third.
    test-lex-is-K4 = {
      expr = edgeMap lex;
      expected = {
        ${c lex "u" "u"} = neigh lex [
          {
            x = "v";
            y = "u";
          }
          {
            x = "v";
            y = "v";
          }
          {
            x = "u";
            y = "v";
          }
        ];
        ${c lex "u" "v"} = neigh lex [
          {
            x = "v";
            y = "u";
          }
          {
            x = "v";
            y = "v";
          }
          {
            x = "u";
            y = "u";
          }
        ];
        ${c lex "v" "u"} = neigh lex [
          {
            x = "u";
            y = "u";
          }
          {
            x = "u";
            y = "v";
          }
          {
            x = "v";
            y = "v";
          }
        ];
        ${c lex "v" "v"} = neigh lex [
          {
            x = "u";
            y = "u";
          }
          {
            x = "u";
            y = "v";
          }
          {
            x = "v";
            y = "u";
          }
        ];
      };
    };
  };
}
