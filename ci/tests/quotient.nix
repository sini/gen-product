# quotient (law P12): soundness — every input edge u -> v yields quotient edge [u] -> [v]; completeness
# — every quotient edge C -> C' is witnessed by some member edge. The quotient map is a strict graph
# homomorphism (Mokhov 2017 §4); node/edge orders are pinned first-seen; keepSelfLoops = false removes
# exactly the intra-class loops.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  gp = genProduct;

  # hosts-by-class fixture: five hosts in two classes, with edges within and across classes.
  cA = {
    id_hash = "cA";
    name = "A";
  };
  cB = {
    id_hash = "cB";
    name = "B";
  };
  hostData = {
    h1 = {
      class = cA;
    };
    h2 = {
      class = cA;
    };
    h3 = {
      class = cB;
    };
    h4 = {
      class = cB;
    };
    h5 = {
      class = cA;
    };
  };
  edges = {
    h1 = [
      "h2"
      "h3"
    ]; # intra-class (h2) + cross-class (h3)
    h2 = [ "h1" ];
    h3 = [ "h4" ]; # intra-class B
    h4 = [ "h1" ]; # cross-class B->A
    h5 = [ ];
  };
  hostsGraph = {
    nodes = [
      "h1"
      "h2"
      "h3"
      "h4"
      "h5"
    ];
    edges = id: edges.${id} or [ ];
    parent = _: null;
    nodeData = id: hostData.${id};
  };

  q = gp.quotient hostsGraph { classOf = h: h.class; };
  qNoLoops = gp.quotient hostsGraph {
    classOf = h: h.class;
    keepSelfLoops = false;
  };

  classOf = id: hostData.${id}.class.id_hash;
  # soundness oracle: for every input edge u->v, [u]->[v] must be a quotient edge.
  soundness = lib.all (
    u: lib.all (v: lib.elem (classOf v) (q.edges (classOf u))) (edges.${u} or [ ])
  ) hostsGraph.nodes;
  # completeness oracle: every quotient edge is witnessed by a member edge.
  completeness = lib.all (
    C:
    lib.all (Ct: lib.any (m: lib.any (t: classOf t == Ct) (edges.${m} or [ ])) (q.nodeData C).members) (
      q.edges C
    )
  ) q.nodes;
in
{
  flake.tests.quotient = {
    # pinned first-seen class order.
    test-class-nodes-pinned = {
      expr = q.nodes;
      expected = [
        "cA"
        "cB"
      ];
    };
    # members grouped, in input node order.
    test-class-members = {
      expr = map (C: (q.nodeData C).members) q.nodes;
      expected = [
        [
          "h1"
          "h2"
          "h5"
        ]
        [
          "h3"
          "h4"
        ]
      ];
    };
    test-soundness = {
      expr = soundness;
      expected = true;
    };
    test-completeness = {
      expr = completeness;
      expected = true;
    };
    # cA has an intra-class loop (h1->h2) and a cross edge (h1->h3 => cA->cB); cB->cA (h4->h1) and
    # an intra-class loop (h3->h4 => cB->cB). keepSelfLoops = true keeps the loops.
    test-edges-with-loops = {
      expr = {
        cA = lib.sort lib.lessThan (q.edges "cA");
        cB = lib.sort lib.lessThan (q.edges "cB");
      };
      expected = {
        cA = [
          "cA"
          "cB"
        ];
        cB = [
          "cA"
          "cB"
        ];
      };
    };
    # keepSelfLoops = false removes exactly the intra-class loops.
    test-edges-no-loops = {
      expr = {
        cA = lib.sort lib.lessThan (qNoLoops.edges "cA");
        cB = lib.sort lib.lessThan (qNoLoops.edges "cB");
      };
      expected = {
        cA = [ "cB" ];
        cB = [ "cA" ];
      };
    };
  };
}
