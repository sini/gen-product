# restrict-membership (law P11): the restricted graph is the induced subgraph on members per the
# three-clause rule; predicate-only adjacency never enumerates (throwing-nodes fixture); explicit
# `cells` lists are first-seen-deduplicated, order preserved, never silently reordered; join
# enumeration (strategy 2) equals filtered full enumeration (strategy 3) as a set with pinned order;
# restrict∘restrict conjoins; `cell` on a non-member is a definition-time error.
{
  lib,
  genProduct,
  graph,
  ...
}:
let
  fx = import ./_fixtures/graphs.nix { inherit lib graph; };
  inherit (fx)
    registryFactor
    idFactor
    hosts
    users
    ;
  gp = genProduct;

  hf = registryFactor "host" hosts;
  uf = registryFactor "user" users;
  p = gp.productN "cartesian" [
    hf
    uf
  ];

  cellIds = prod: map (c: prod.product.cellOf c) (gp.cells prod);
  idSet = prod: lib.sort lib.lessThan (cellIds prod);

  # clause 1 — explicit cells.
  byCells = gp.restrict p {
    cells = [
      {
        host = hosts.H_axon01;
        user = users.U_sini;
      }
      {
        host = hosts.H_blade01;
        user = users.U_vic;
      }
    ];
  };
  # clause 2 — relations (natural join).
  byRel = gp.restrict p {
    relations = [
      {
        dims = [
          "host"
          "user"
        ];
        pairs = [
          {
            host = hosts.H_axon01;
            user = users.U_sini;
          }
          {
            host = hosts.H_axon02;
            user = users.U_vic;
          }
        ];
      }
    ];
  };
  # clause 3 — predicate.
  byPred = gp.restrict p {
    predicate = coords: coords.user.id_hash == "U_sini";
  };

  # join (two covering relations) vs filtered-full (equivalent predicate).
  joinR = gp.restrict p {
    relations = [
      {
        dims = [ "host" ];
        pairs = [
          { host = hosts.H_axon01; }
          { host = hosts.H_blade01; }
        ];
      }
      {
        dims = [ "user" ];
        pairs = [ { user = users.U_sini; } ];
      }
    ];
  };
  filterR = gp.restrict p {
    predicate =
      coords:
      lib.elem coords.host.id_hash [
        "H_axon01"
        "H_blade01"
      ]
      && coords.user.id_hash == "U_sini";
  };

  # restrict∘restrict conjunction.
  conj = gp.restrict byPred {
    predicate = coords: coords.host.id_hash == "H_axon01";
  };

  # predicate-only restriction over a throwing-nodes factor — adjacency must never enumerate.
  throwingGraph = {
    nodes = throw "P11: nodes must not be forced on the adjacency path";
    edges = id: if id == "t0" then [ "t1" ] else [ ];
    parent = _: null;
    nodeData = id: id;
  };
  tp =
    gp.restrict
      (gp.productN "cartesian" [
        (idFactor "t" throwingGraph)
        (idFactor "y" fx.gB)
      ])
      {
        predicate = _: true;
      };

  nonMember = builtins.tryEval (
    gp.cell byCells {
      host = hosts.H_axon01;
      user = users.U_vic;
    }
  );

  # cells-list order + dedup: given order preserved, first-seen dedup.
  ordered = gp.restrict p {
    cells = [
      {
        host = hosts.H_blade01;
        user = users.U_vic;
      }
      {
        host = hosts.H_axon01;
        user = users.U_sini;
      }
      {
        host = hosts.H_blade01;
        user = users.U_vic;
      } # duplicate
    ];
  };
in
{
  flake.tests.restrict-membership = {
    test-clause1-cells = {
      expr = lib.length (gp.cells byCells);
      expected = 2;
    };
    test-clause2-relations = {
      expr = lib.length (gp.cells byRel);
      expected = 2;
    };
    test-clause3-predicate = {
      expr = lib.all (c: c.user.id_hash == "U_sini") (gp.cells byPred);
      expected = true;
    };
    # induced adjacency: an edge to a non-member is dropped. axon01/sini has no cartesian neighbour
    # among members (users/hosts here are edgeless factors), so its edge list is empty.
    test-induced-drops-nonmembers = {
      expr = byCells.edges (
        gp.cell byCells {
          host = hosts.H_axon01;
          user = users.U_sini;
        }
      );
      expected = [ ];
    };
    # join (strategy 2) == filtered full (strategy 3) as a SET.
    test-join-equals-filter = {
      expr = idSet joinR;
      expected = idSet filterR;
    };
    # join enumeration is pinned (declared relation/pair order, row-major).
    test-join-pinned-order = {
      expr = map (c: c.host.id_hash) (gp.cells joinR);
      expected = [
        "H_axon01"
        "H_blade01"
      ];
    };
    # restrict∘restrict = intersection.
    test-conjunction = {
      expr = map (c: {
        h = c.host.id_hash;
        u = c.user.id_hash;
      }) (gp.cells conj);
      expected = [
        {
          h = "H_axon01";
          u = "U_sini";
        }
      ];
    };
    # predicate-only adjacency never enumerates the throwing-nodes product.
    test-predicate-adjacency-no-enumerate = {
      expr =
        (builtins.tryEval (
          builtins.deepSeq (tp.edges (
            gp.cell tp {
              t = "t0";
              y = "b0";
            }
          )) true
        )).success;
      expected = true;
    };
    # cells list: first-seen dedup, given order preserved (no silent reorder).
    test-cells-order-dedup = {
      expr = map (c: {
        h = c.host.id_hash;
        u = c.user.id_hash;
      }) (gp.cells ordered);
      expected = [
        {
          h = "H_blade01";
          u = "U_vic";
        }
        {
          h = "H_axon01";
          u = "U_sini";
        }
      ];
    };
    # cell on a non-member throws.
    test-cell-non-member-errors = {
      expr = nonMember.success;
      expected = false;
    };
  };
}
