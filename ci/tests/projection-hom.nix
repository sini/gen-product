# projection-hom (law P5): the honest per-kind homomorphism table (Handbook of Product Graphs).
#   tensor        — projections are STRICT homomorphisms (every product edge maps to a factor edge);
#   cartesian     — WEAK (each edge maps to an edge OR collapses to a single vertex);
#   strong        — WEAK;
#   lexicographic — LEADING projection weak; TRAILING projections carry no homomorphism claim
#                   (counterexample fixture asserted).
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

  prodEdges =
    p:
    lib.concatMap (
      c:
      let
        cid = p.product.cellOf c;
      in
      map (t: {
        src = cid;
        dst = t;
      }) (p.edges cid)
    ) (gp.cells p);

  edgeIn =
    proj: a: b:
    lib.elem b (proj.edges a);
  # weak: edge OR collapse; strict: edge.
  weakOk =
    proj: ed:
    let
      a = proj.projection.ofCell ed.src;
      b = proj.projection.ofCell ed.dst;
    in
    a == b || edgeIn proj a b;
  strictOk =
    proj: ed:
    let
      a = proj.projection.ofCell ed.src;
      b = proj.projection.ofCell ed.dst;
    in
    edgeIn proj a b;

  bin =
    f:
    gp.productN f [
      (idFactor "x" fx.gB)
      (idFactor "y" fx.gB)
    ];

  tens = bin "tensor";
  cart = bin "cartesian";
  strong = bin "strong";

  lexF = [
    (idFactor "x" fx.gA)
    (idFactor "y" fx.gChain)
  ];
  lex = gp.productN "lexicographic" lexF;
in
{
  flake.tests.projection-hom = {
    # tensor: both projections strict.
    test-tensor-x-strict = {
      expr = lib.all (strictOk (gp.projectTo tens "x")) (prodEdges tens);
      expected = true;
    };
    test-tensor-y-strict = {
      expr = lib.all (strictOk (gp.projectTo tens "y")) (prodEdges tens);
      expected = true;
    };
    # cartesian: weak (and NOT strict — a collapsing edge exists, so the strict claim is false).
    test-cartesian-x-weak = {
      expr = lib.all (weakOk (gp.projectTo cart "x")) (prodEdges cart);
      expected = true;
    };
    test-cartesian-x-not-strict = {
      expr = lib.all (strictOk (gp.projectTo cart "x")) (prodEdges cart);
      expected = false;
    };
    # strong: weak.
    test-strong-y-weak = {
      expr = lib.all (weakOk (gp.projectTo strong "y")) (prodEdges strong);
      expected = true;
    };
    # lex: leading (x) weak; trailing (y) NOT a homomorphism (some edge is neither edge nor collapse).
    test-lex-leading-weak = {
      expr = lib.all (weakOk (gp.projectTo lex "x")) (prodEdges lex);
      expected = true;
    };
    test-lex-trailing-not-hom = {
      expr = lib.any (ed: !(weakOk (gp.projectTo lex "y") ed)) (prodEdges lex);
      expected = true;
    };
  };
}
