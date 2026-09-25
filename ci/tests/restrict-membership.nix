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

  # ── the membership index (den-hoag-bksu) ──
  # An index's shape: attrset-ness and its distinct-key count. A key LIST (the rescan's shape) reads
  # isAttrs = false, keys = -1.
  shapeOf = i: {
    isAttrs = builtins.isAttrs i;
    keys = if builtins.isAttrs i then lib.length (builtins.attrNames i) else -1;
  };
  keysOf = i: builtins.attrNames i;
  cid =
    h: u:
    builtins.toJSON [
      h
      u
    ];

  # restrict ∘ restrict over two cells clauses (class member 3, `conjoin`) and over two relations.
  conjCells = gp.restrict byCells {
    cells = [
      {
        host = hosts.H_axon01;
        user = users.U_sini;
      }
    ];
  };
  conjRels = gp.restrict byRel {
    relations = [
      {
        dims = [ "user" ];
        pairs = [ { user = users.U_sini; } ];
      }
    ];
  };

  # Parity fixture: an 8×8 edgeless identity-codec product with hit and miss coordinates for every
  # clause shape. The expected answers come from a brute-force oracle over the raw membership data
  # (`lib.elem` on the declared lists), independent of the library's index.
  sqF =
    n:
    idFactor n {
      nodes = map (i: "${n}${toString i}") (lib.range 0 7);
      edges = _: [ ];
      parent = _: null;
      nodeData = id: id;
    };
  sq = gp.productN "cartesian" [
    (sqF "a")
    (sqF "b")
  ];
  at = i: j: {
    a = "a${toString i}";
    b = "b${toString j}";
  };
  sqCoords = lib.concatMap (i: map (at i) (lib.range 0 7)) (lib.range 0 7);
  diag = map (i: at i i) [
    0
    2
    4
    6
  ];
  anti = map (i: at i (7 - i)) (lib.range 0 4);
  sqCells = gp.restrict sq { cells = diag; };
  sqRel = gp.restrict sq {
    relations = [
      {
        dims = [
          "a"
          "b"
        ];
        pairs = anti;
      }
    ];
  };
  narrowCells = [
    (at 2 2)
    (at 3 3)
    (at 4 4)
  ];
  narrowRel = [
    (at 1 6)
    (at 5 5)
    (at 2 5)
  ];
  sqConjCells = gp.restrict sqCells { cells = narrowCells; };
  sqConjRelCells = gp.restrict sqRel { cells = narrowRel; };
  parity = [
    {
      r = sqCells;
      oracle = c: lib.elem c diag;
    }
    {
      r = sqRel;
      oracle = c: lib.elem c anti;
    }
    {
      r = sqConjCells;
      oracle = c: lib.elem c diag && lib.elem c narrowCells;
    }
    {
      r = sqConjRelCells;
      oracle = c: lib.elem c anti && lib.elem c narrowRel;
    }
  ];
  sortedIds = cs: lib.sort lib.lessThan (map sq.product.cellOf cs);
  answersOf = x: {
    accepted = map (c: (builtins.tryEval (gp.cell x.r c)).success) sqCoords;
    members = sortedIds (gp.cells x.r);
  };
  oracleOf = x: {
    accepted = map x.oracle sqCoords;
    members = sortedIds (lib.filter x.oracle sqCoords);
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
    # The membership index is a materialized attrset field of the normalized restriction record, one
    # attribute per DISTINCT key (`ordered` lists a cell twice) — not a key list scanned per probe.
    test-membership-index-is-an-attrset = {
      expr = {
        cells = shapeOf ordered.product.restriction.cellIndex;
        relations = map shapeOf byRel.product.restriction.relationIndexes;
        cellsLess = byRel.product.restriction.cellIndex;
      };
      expected = {
        cells = {
          isAttrs = true;
          keys = 2;
        };
        relations = [
          {
            isAttrs = true;
            keys = 2;
          }
        ];
        cellsLess = null;
      };
    };
    # Index answers equal the scan's: acceptance by `cell` over all 64 coordinates and the member set,
    # per clause shape, against the brute-force oracle. The hit counts pin that every shape has both
    # hits and misses.
    test-index-answers-agree-with-scan = {
      expr = {
        identical = map (x: answersOf x == oracleOf x) parity;
        hits = map (x: lib.length (lib.filter (b: b) (answersOf x).accepted)) parity;
      };
      expected = {
        identical = [
          true
          true
          true
          true
        ];
        hits = [
          4
          5
          2
          2
        ];
      };
    };
    # One sub-assertion per class member, each on a restriction that forces exactly that clause:
    # relationMatch (relations), isMember c1 (cells), conjoin (restrict ∘ restrict, which carries both
    # operands' indexes rather than re-deriving them).
    test-index-covers-all-three-class-members = {
      expr = {
        relationMatch = map keysOf byRel.product.restriction.relationIndexes;
        c1 = keysOf byCells.product.restriction.cellIndex;
        conjoin = {
          cellIndex = keysOf conjCells.product.restriction.cellIndex;
          relationIndexes = map keysOf conjRels.product.restriction.relationIndexes;
        };
      };
      expected = {
        relationMatch = [
          [
            (cid "H_axon01" "U_sini")
            (cid "H_axon02" "U_vic")
          ]
        ];
        c1 = [
          (cid "H_axon01" "U_sini")
          (cid "H_blade01" "U_vic")
        ];
        conjoin = {
          cellIndex = [ (cid "H_axon01" "U_sini") ];
          relationIndexes = [
            [
              (cid "H_axon01" "U_sini")
              (cid "H_axon02" "U_vic")
            ]
            [ (builtins.toJSON [ "U_sini" ]) ]
          ];
        };
      };
    };
  };
}
