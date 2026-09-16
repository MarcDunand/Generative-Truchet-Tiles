import processing.svg.*;
import java.util.Collections;
import java.util.Comparator;
import java.util.*;

// Non-intersecting Truchet, "parallel" approach.
//
// Same front end as old_intersection_version: one closed random scribble, every
// crossing of a grid line filed under both tiles that share that line, so each
// tile ends up with an even number of boundary points and every point is drawn
// to from both sides (which is what closes every shape).
//
// What is new is how a tile's points get paired. The old version used a random
// non-crossing matching, which is only non-crossing *topologically* -- the arcs
// are rigid, so a legal nesting can still produce two arcs that physically
// cross. This version pairs by:
//
//   1: connect the smallest available corner, repeat until no corners remain
//   2: connect the remaining points in any non-crossing manner
//
// where a "corner" is a pair on two adjacent edges (drawn as a quarter ellipse
// hugging the shared tile corner) and "smallest" means least average of the two
// legs, a leg being the distance from that tile corner along each edge.
//
// Why step 1 is safe: if the minimal corner has legs a and b, no other point can
// lie inside the region it encloses -- such a point would sit at leg t < a (or
// l < b) and pair with the opposite leg's point to give a corner of sum t + b,
// which is smaller. So closing it consumes space nothing else needs; delete
// those two points and the same argument applies to what is left.
//
// A useful consequence: the minimal corner's two points are always *cyclically
// adjacent* among the remaining points (the arc of the cycle it cuts off is
// exactly the region proved empty above), so step 1 can never produce a crossing
// pair, and the points it leaves behind stay in cyclic order for step 2.
//
// Why step 2 is safe: once no corner is available, no two occupied edges are
// adjacent, so every remaining point lies on one edge or on two opposite edges.
// Pairs are then only "sides" (same edge, half circle) or "crosses" (opposite
// edges, S curve), and a non-crossing matching makes the sides nested and the
// crosses ordered. Crosses cannot reach a side (a cross's tangent never exceeds
// 45 degrees, a side's reaches exactly 45), sides cannot reach sides, parallel
// crosses cannot reach each other, and non-parallel crosses cannot occur because
// they would need points on adjacent edges -- already consumed by step 1.

int gridN = 4;
int scribbleLen = 50;
float lineSep = 10;  // minimum spacing between points along a grid line; 0 disables
boolean debugGrid = false;
// Fill instead of stroke, flipping colour at every line: outside white, inside
// one curve black, inside two white, and so on. ("2coloring" is not a legal Java
// name -- identifiers cannot start with a digit.)
boolean twoColoring = true;

// edge indices into a cell's point lists
final int TOP = 0, RIGHT = 1, BOTTOM = 2, LEFT = 3;

// the four tile corners, each as {edgeA, endA, edgeB, endB}
// end 0 = front of that edge's sorted list, end 1 = back
final int[][] CORNERS = {
  {TOP,    0, LEFT,  0},  // top-left
  {TOP,    1, RIGHT, 0},  // top-right
  {BOTTOM, 1, RIGHT, 1},  // bottom-right
  {BOTTOM, 0, LEFT,  1}   // bottom-left
};

// every pair drawn, plus the cell it was drawn in; only collected for twoColoring
ArrayList<PVector[]> allPairs = new ArrayList<PVector[]>();
ArrayList<int[]> allPairCells = new ArrayList<int[]>();

ArrayList<PVector> vList = new ArrayList<PVector>();
// iArr[y][x][edge] -> the points of cell (x,y) lying on that edge
ArrayList<ArrayList<ArrayList<ArrayList<PVector>>>> iArr = new ArrayList<ArrayList<ArrayList<ArrayList<PVector>>>>();

// debug
int nCornerPairs = 0;
int nLeftoverPairs = 0;
int nCellsWithLeftover = 0;
int nOddCells = 0;
int nPointsDropped = 0;
int nSacrificed = 0;
int nForcedKeeps = 0;


float findSlope(float x1, float y1, float x2, float y2) {
  return (y2 - y1) / (x2 - x1);
}


// The coordinate a point varies along on its own grid line.
float coordOn(PVector p, boolean vertical) {
  return vertical ? p.y : p.x;
}


// Enforce a minimum spacing along one grid-line segment.
//
// Points are never deleted per cell -- they are deleted per segment, and every
// segment is the shared border of exactly two cells, so dropping k points drops
// the same k from both of them. Dropping an EVEN number therefore leaves both
// cells with an even point count, which is all that closure needs.
//
// The segment's own two ends count as points too. They are the grid corners, and
// a mark landing next to one produces a corner arc with a near-zero leg -- four
// cells meet at every grid corner, so those tiny arcs pile into a knot that no
// per-cell check can see.
//
// A corner only asks for HALF of minSep, because the constraint is enforced from
// both sides of it independently: the segment above an intersection and the one
// below it are thinned separately, so two marks straddling that corner are each
// held minSep/2 clear and still end up a full minSep apart from each other.
//
// One sweep is enough: deleting a point merges its two gaps into a single larger
// one, so a deletion can never open a new violation.
//
// pts must already be sorted along the segment. Returns how many were dropped.
int thinEdge(ArrayList<PVector> pts, boolean vertical, float minSep,
             float segStart, float segEnd) {
  int n = pts.size();
  if (n == 0 || minSep <= 0) return 0;

  float halfSep = minSep / 2;
  boolean[] drop = new boolean[n];
  int dropped = 0;

  // Seeding the sweep half a step behind the near corner asks the first survivor
  // for halfSep of corner clearance while every later one still owes a full
  // minSep to the mark before it. Only the first needs the corner test: anything
  // clearing minSep from a mark that already cleared halfSep clears it by more.
  float lastKept = segStart - halfSep;
  for (int i = 0; i < n; i++) {
    float c = coordOn(pts.get(i), vertical);
    if (c - lastKept < minSep) {
      drop[i] = true;
      dropped++;
    } else {
      lastKept = c;
    }
  }

  // Only the last survivor can foul the far corner: survivors are already minSep
  // apart, so once one clears the end every earlier one clears it by more.
  for (int i = n - 1; i >= 0; i--) {
    if (drop[i]) continue;
    if (segEnd - coordOn(pts.get(i), vertical) < halfSep) {
      drop[i] = true;
      dropped++;
    }
    break;
  }

  // An odd number of deletions would flip both neighbouring cells to an odd
  // point count, so even it up.
  if ((dropped & 1) == 1) {
    if (dropped < n) {
      // Sacrifice a legal point: the survivor with the least slack, measured
      // against whichever rule binds it -- halfSep at a corner, minSep to a mark.
      int lastSurvivor = -1;
      for (int i = 0; i < n; i++) {
        if (!drop[i]) lastSurvivor = i;
      }

      int victim = -1;
      float tightest = Float.MAX_VALUE;
      float prev = segStart;
      boolean first = true;
      for (int i = 0; i < n; i++) {
        if (drop[i]) continue;
        float c = coordOn(pts.get(i), vertical);
        float slack = first ? (c - segStart) - halfSep : (c - prev) - minSep;
        if (i == lastSurvivor) slack = min(slack, (segEnd - c) - halfSep);
        if (slack < tightest) {
          tightest = slack;
          victim = i;
        }
        prev = c;
        first = false;
      }
      drop[victim] = true;
      dropped++;
      nSacrificed++;
    } else {
      // A segment can only ever shed an EVEN number of points, so one holding an
      // odd number always keeps at least one -- even when the sweep wanted them
      // all gone. Put back the one furthest from either corner, the least bad of
      // them. Parity wins here; closure depends on it, spacing is cosmetic.
      int keep = -1;
      float best = -1;
      for (int i = 0; i < n; i++) {
        float c = coordOn(pts.get(i), vertical);
        float clear = min(c - segStart, segEnd - c);
        if (clear > best) {
          best = clear;
          keep = i;
        }
      }
      drop[keep] = false;
      dropped--;
      nForcedKeeps++;
    }
  }

  for (int i = n - 1; i >= 0; i--) {
    if (drop[i]) pts.remove(i);
  }
  return dropped;
}


// Distance from p to the tile corner named by (edge, end), measured along edge.
// Front of an edge is its low-coordinate end, back is its high-coordinate end.
float legLength(int edge, int end, PVector p, float gridL, int cx, int cy) {
  float lo, coord;
  if (edge == TOP || edge == BOTTOM) {
    lo = cx * gridL;
    coord = p.x;
  } else {
    lo = cy * gridL;
    coord = p.y;
  }
  return end == 0 ? coord - lo : (lo + gridL) - coord;
}


// Step 1: repeatedly close the smallest remaining corner.
//
// The minimum of (legA + legB) over one pair of adjacent edges is reached by the
// point nearest that tile corner on each edge, so only four candidates -- one per
// tile corner -- ever need checking. Removals therefore only ever happen at the
// front or back of an edge's sorted list, which is what lo[]/hi[] track.
ArrayList<PVector[]> connectCorners(ArrayList<ArrayList<PVector>> cell, int[] lo, int[] hi,
                                    float gridL, int cx, int cy) {
  ArrayList<PVector[]> pairs = new ArrayList<PVector[]>();

  while (true) {
    int best = -1;
    float bestSum = Float.MAX_VALUE;

    for (int c = 0; c < 4; c++) {
      int eA = CORNERS[c][0], endA = CORNERS[c][1];
      int eB = CORNERS[c][2], endB = CORNERS[c][3];
      if (lo[eA] > hi[eA] || lo[eB] > hi[eB]) continue;  // an edge is empty

      PVector pA = cell.get(eA).get(endA == 0 ? lo[eA] : hi[eA]);
      PVector pB = cell.get(eB).get(endB == 0 ? lo[eB] : hi[eB]);
      float sum = legLength(eA, endA, pA, gridL, cx, cy)
                + legLength(eB, endB, pB, gridL, cx, cy);

      if (sum < bestSum) {
        bestSum = sum;
        best = c;
      }
    }

    if (best < 0) break;  // no two adjacent edges still hold points

    int eA = CORNERS[best][0], endA = CORNERS[best][1];
    int eB = CORNERS[best][2], endB = CORNERS[best][3];
    PVector pA = cell.get(eA).get(endA == 0 ? lo[eA]++ : hi[eA]--);
    PVector pB = cell.get(eB).get(endB == 0 ? lo[eB]++ : hi[eB]--);
    pairs.add(new PVector[] { pA, pB });
  }

  return pairs;
}


// What survives step 1, walked clockwise from the top-left tile corner so that
// step 2's matching is non-crossing in the tile's own cyclic order.
ArrayList<PVector> leftoverInCyclicOrder(ArrayList<ArrayList<PVector>> cell, int[] lo, int[] hi) {
  ArrayList<PVector> cyc = new ArrayList<PVector>();
  for (int i = lo[TOP];    i <= hi[TOP];    i++) cyc.add(cell.get(TOP).get(i));     // x ascending
  for (int i = lo[RIGHT];  i <= hi[RIGHT];  i++) cyc.add(cell.get(RIGHT).get(i));   // y ascending
  for (int i = hi[BOTTOM]; i >= lo[BOTTOM]; i--) cyc.add(cell.get(BOTTOM).get(i));  // x descending
  for (int i = hi[LEFT];   i >= lo[LEFT];   i--) cyc.add(cell.get(LEFT).get(i));    // y descending
  return cyc;
}


// log of the Catalan numbers C[0..maxN], via C[n] = (2n)! / (n! (n+1)!).
// Kept in log space because the weights below are products of two Catalans, and
// a plain double overflows to infinity once a cell's leftover set gets large.
double[] logCatalanNumbers(int maxN) {
  double[] logFact = new double[2 * maxN + 2];
  logFact[0] = 0.0;
  for (int k = 1; k < logFact.length; k++) {
    logFact[k] = logFact[k - 1] + Math.log(k);
  }
  double[] logC = new double[maxN + 1];
  for (int n = 0; n <= maxN; n++) {
    logC[n] = logFact[2 * n] - logFact[n] - logFact[n + 1];
  }
  return logC;
}


// Step 2: a uniformly random non-crossing perfect matching of pts, which must
// already be in cyclic order. For interval [L,R] each legal partner k of L is
// weighted by C[a/2] * C[b/2] -- the number of ways each side could then be
// completed -- so every non-crossing matching comes out equally likely.
ArrayList<PVector[]> connectPts(ArrayList<PVector> pts) {
  ArrayList<PVector[]> pairs = new ArrayList<PVector[]>();
  int n = pts.size();
  if (n == 0) return pairs;
  if ((n & 1) == 1) {
    println("connectPts: WARNING: called with odd number of points (" + n + ")");
    return pairs;
  }

  double[] logC = logCatalanNumbers(n / 2);

  Deque<int[]> stack = new ArrayDeque<int[]>();
  stack.push(new int[]{0, n - 1});

  while (!stack.isEmpty()) {
    int[] interval = stack.pop();
    int L = interval[0];
    int R = interval[1];

    int m = R - L + 1;
    if (m <= 0) continue;
    if (m == 2) {
      pairs.add(new PVector[] { pts.get(L), pts.get(R) });
      continue;
    }

    // L's legal partners are L+1, L+3, ..., R (an even count must remain on each side)
    ArrayList<Integer> options = new ArrayList<Integer>();
    for (int k = L + 1; k <= R; k += 2) {
      options.add(k);
    }

    // weigh each option by how many non-crossing matchings it leaves reachable,
    // then shift by the largest so the exponentials stay in range
    double[] logW = new double[options.size()];
    double maxLogW = Double.NEGATIVE_INFINITY;
    for (int i = 0; i < options.size(); i++) {
      int k = options.get(i);
      int a = k - L - 1;  // points strictly between L and k
      int b = R - k;      // points strictly between k and R
      logW[i] = logC[a / 2] + logC[b / 2];
      if (logW[i] > maxLogW) maxLogW = logW[i];
    }

    double[] weights = new double[options.size()];
    double totalWeight = 0.0;
    for (int i = 0; i < options.size(); i++) {
      weights[i] = Math.exp(logW[i] - maxLogW);
      totalWeight += weights[i];
    }

    double r = random((float)totalWeight);
    double acc = 0.0;
    int chosenK = options.get(options.size() - 1);  // fallback
    for (int i = 0; i < options.size(); i++) {
      acc += weights[i];
      if (r <= acc) {
        chosenK = options.get(i);
        break;
      }
    }

    pairs.add(new PVector[] { pts.get(L), pts.get(chosenK) });

    if (chosenK - L > 1) stack.push(new int[]{L + 1, chosenK - 1});
    if (R - chosenK > 0) stack.push(new int[]{chosenK + 1, R});
  }

  return pairs;
}


// Draw the arc(s) joining two points on the boundary of cell (cx, cy).
// Identical geometry to both earlier versions: every case meets the tile edge at
// a right angle, which is what lets curves from adjacent tiles continue as one
// smooth line and what rules out sharp corners.
void drawPair(float gridL, int cx, int cy, PVector p1, PVector p2) {
  float x1, y1, x2, y2;
  if (p1.x > p2.x) {
    x1 = p1.x; y1 = p1.y;
    x2 = p2.x; y2 = p2.y;
  } else {
    x2 = p1.x; y2 = p1.y;
    x1 = p2.x; y1 = p2.y;
  }

  float startAng;

  if (x1 == x2) {  // side, on the left or right edge
    startAng = x1 == cx * gridL ? (3 * PI) / 2 : PI / 2;
    arc(x1, (y1 + y2) / 2, abs(y1 - y2), abs(y1 - y2), startAng, startAng + PI);
  } else if (y1 == y2) {  // side, on the top or bottom edge
    startAng = y1 == cy * gridL ? 0 : PI;
    arc((x1 + x2) / 2, y1, abs(x1 - x2), abs(x1 - x2), startAng, startAng + PI);
  } else if (abs(x1 - x2) == gridL) {  // cross, left to right
    float s = (y2 - y1) / (x2 - x1);
    if (s > 0) {
      arc(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI);
      arc(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2 * PI);
    } else if (s == 0) {
      line(x1, y1, x2, y2);
    } else {
      arc(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2);
      arc(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), 0, PI / 2);
    }
  } else if (abs(y1 - y2) == gridL) {  // cross, top to bottom
    float s = (y2 - y1) / (x2 - x1);
    if (s > 0) {
      arc((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI);
      arc((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2 * PI);
    } else if (s == 0) {
      line(x1, y1, x2, y2);
    } else {
      arc((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2);
      arc((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), 0, PI / 2);
    }
  } else {  // corner
    if (y1 < y2) {
      if (cy * gridL == y1) {
        arc(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), 0, PI / 2);
      } else {
        arc(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI, (3 * PI) / 2);
      }
    } else {
      if ((cy + 1) * gridL == y1) {
        arc(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), (3 * PI) / 2, 2 * PI);
      } else {
        arc(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI / 2, PI);
      }
    }
  }
}


// ---------------------------------------------------------------------------
// Two-colouring
//
// The arcs of a finished drawing form disjoint simple closed curves -- that is
// exactly what this version of the algorithm guarantees -- so the plane they cut
// up is two-colourable, and a region's colour is just the parity of how many
// curves contain it. Outside is inside nothing, so it is white; step over one
// line and the count goes to 1, black; over another and it is 2, white again.
//
// Rendering it takes three passes: rebuild the closed curves from the pairs,
// work out each one's parity, then fill them outermost first so that an inner
// curve repaints its own interior in the opposite colour.
// ---------------------------------------------------------------------------

class Loop {
  ArrayList<PVector> poly;
  float minX, minY, maxX, maxY;
  float absArea;
  PVector rep;      // a point strictly inside this curve
  boolean black;
}


// Sample one axis-aligned elliptical arc, in Processing's arc() convention:
// centre (ex, ey), w and h are DIAMETERS, angles run t0 -> t1.
ArrayList<PVector> sampleArc(float ex, float ey, float w, float h, float t0, float t1) {
  float rx = w / 2, ry = h / 2;
  float span = abs(t1 - t0);
  int n = (int)constrain(span * max(rx, ry) / 2.0, 4, 120);

  ArrayList<PVector> out = new ArrayList<PVector>();
  for (int i = 0; i <= n; i++) {
    float t = t0 + (t1 - t0) * i / (float)n;
    out.add(new PVector(ex + rx * cos(t), ey + ry * sin(t)));
  }
  return out;
}


// Stitch the pieces of one pair into a single path starting at `start`. A cross
// comes back as two quarter ellipses that meet at a midpoint, and they are not
// guaranteed to be generated nose-to-tail, so each piece is oriented as it goes.
ArrayList<PVector> chainFrom(ArrayList<ArrayList<PVector>> parts, PVector start) {
  ArrayList<PVector> path = new ArrayList<PVector>();
  boolean[] used = new boolean[parts.size()];
  PVector cur = start;

  for (int k = 0; k < parts.size(); k++) {
    int bestIdx = -1;
    boolean reverse = false;
    float bestD = Float.MAX_VALUE;

    for (int i = 0; i < parts.size(); i++) {
      if (used[i]) continue;
      ArrayList<PVector> pl = parts.get(i);
      float dHead = dist(cur.x, cur.y, pl.get(0).x, pl.get(0).y);
      float dTail = dist(cur.x, cur.y, pl.get(pl.size() - 1).x, pl.get(pl.size() - 1).y);
      if (dHead < bestD) { bestD = dHead; bestIdx = i; reverse = false; }
      if (dTail < bestD) { bestD = dTail; bestIdx = i; reverse = true; }
    }

    used[bestIdx] = true;
    ArrayList<PVector> pl = parts.get(bestIdx);
    if (reverse) {
      int from = pl.size() - 1;
      if (!path.isEmpty()) from--;  // skip the duplicated joint
      for (int i = from; i >= 0; i--) path.add(pl.get(i));
    } else {
      for (int i = path.isEmpty() ? 0 : 1; i < pl.size(); i++) path.add(pl.get(i));
    }
    cur = path.get(path.size() - 1);
  }
  return path;
}


// The same geometry drawPair strokes, returned as a polyline running p1 -> p2.
// Kept deliberately parallel to drawPair: if one changes, the other must too.
ArrayList<PVector> pairPolyline(float gridL, int cx, int cy, PVector p1, PVector p2) {
  float x1, y1, x2, y2;
  if (p1.x > p2.x) {
    x1 = p1.x; y1 = p1.y;
    x2 = p2.x; y2 = p2.y;
  } else {
    x2 = p1.x; y2 = p1.y;
    x1 = p2.x; y1 = p2.y;
  }

  ArrayList<ArrayList<PVector>> parts = new ArrayList<ArrayList<PVector>>();
  float startAng;

  if (x1 == x2) {  // side, on the left or right edge
    startAng = x1 == cx * gridL ? (3 * PI) / 2 : PI / 2;
    parts.add(sampleArc(x1, (y1 + y2) / 2, abs(y1 - y2), abs(y1 - y2), startAng, startAng + PI));
  } else if (y1 == y2) {  // side, on the top or bottom edge
    startAng = y1 == cy * gridL ? 0 : PI;
    parts.add(sampleArc((x1 + x2) / 2, y1, abs(x1 - x2), abs(x1 - x2), startAng, startAng + PI));
  } else if (abs(x1 - x2) == gridL) {  // cross, left to right
    float s = (y2 - y1) / (x2 - x1);
    if (s > 0) {
      parts.add(sampleArc(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI));
      parts.add(sampleArc(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2 * PI));
    } else if (s == 0) {
      ArrayList<PVector> seg = new ArrayList<PVector>();
      seg.add(new PVector(x1, y1));
      seg.add(new PVector(x2, y2));
      parts.add(seg);
    } else {
      parts.add(sampleArc(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2));
      parts.add(sampleArc(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), 0, PI / 2));
    }
  } else if (abs(y1 - y2) == gridL) {  // cross, top to bottom
    float s = (y2 - y1) / (x2 - x1);
    if (s > 0) {
      parts.add(sampleArc((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI));
      parts.add(sampleArc((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2 * PI));
    } else if (s == 0) {
      ArrayList<PVector> seg = new ArrayList<PVector>();
      seg.add(new PVector(x1, y1));
      seg.add(new PVector(x2, y2));
      parts.add(seg);
    } else {
      parts.add(sampleArc((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2));
      parts.add(sampleArc((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), 0, PI / 2));
    }
  } else {  // corner
    if (y1 < y2) {
      if (cy * gridL == y1) {
        parts.add(sampleArc(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), 0, PI / 2));
      } else {
        parts.add(sampleArc(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI, (3 * PI) / 2));
      }
    } else {
      if ((cy + 1) * gridL == y1) {
        parts.add(sampleArc(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), (3 * PI) / 2, 2 * PI));
      } else {
        parts.add(sampleArc(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI / 2, PI));
      }
    }
  }

  return chainFrom(parts, p1);
}


// Walk the pairs into closed curves. Every point carries exactly one arc from
// each of the two cells that share its grid line, so the pairs form a 2-regular
// graph and following it from any arc always returns to the start. That degree
// of 2 is the same fact that makes every shape close in the first place.
ArrayList<Loop> buildLoops(float gridL) {
  IdentityHashMap<PVector, Integer> ids = new IdentityHashMap<PVector, Integer>();
  for (PVector[] pr : allPairs) {
    for (int k = 0; k < 2; k++) {
      if (!ids.containsKey(pr[k])) ids.put(pr[k], ids.size());
    }
  }

  int nPts = ids.size();
  int[][] inc = new int[nPts][2];
  int[] deg = new int[nPts];
  for (int i = 0; i < allPairs.size(); i++) {
    PVector[] pr = allPairs.get(i);
    for (int k = 0; k < 2; k++) {
      int v = ids.get(pr[k]);
      if (deg[v] < 2) inc[v][deg[v]] = i;
      deg[v]++;
    }
  }
  int loose = 0;
  for (int v = 0; v < nPts; v++) {
    if (deg[v] != 2) loose++;
  }
  if (loose > 0) {
    println("twoColoring WARNING: " + loose + " points do not have exactly two arcs;"
          + " those curves are not closed and their fill will be wrong");
  }

  ArrayList<Loop> loops = new ArrayList<Loop>();
  boolean[] usedPair = new boolean[allPairs.size()];

  for (int i = 0; i < allPairs.size(); i++) {
    if (usedPair[i]) continue;

    ArrayList<PVector> poly = new ArrayList<PVector>();
    int cur = i;
    PVector curPt = allPairs.get(i)[0];

    while (true) {
      usedPair[cur] = true;
      PVector[] pr = allPairs.get(cur);
      // NB: not named `to` -- that is a Java restricted keyword and Processing's
      // parser rejects it as a variable name
      PVector nextPt = (pr[0] == curPt) ? pr[1] : pr[0];
      int[] c = allPairCells.get(cur);

      ArrayList<PVector> seg = pairPolyline(gridL, c[0], c[1], curPt, nextPt);
      for (int k = poly.isEmpty() ? 0 : 1; k < seg.size(); k++) poly.add(seg.get(k));

      int v = ids.get(nextPt);
      if (deg[v] != 2) break;  // open end, cannot continue
      int nxt = (inc[v][0] == cur) ? inc[v][1] : inc[v][0];
      if (usedPair[nxt]) break;  // back to the start: the curve is closed
      cur = nxt;
      curPt = nextPt;
    }

    if (poly.size() < 3) continue;

    Loop L = new Loop();
    L.poly = poly;
    L.minX = L.maxX = poly.get(0).x;
    L.minY = L.maxY = poly.get(0).y;
    float area2 = 0;
    int topIdx = 0;
    for (int k = 0; k < poly.size(); k++) {
      PVector a = poly.get(k);
      PVector b = poly.get((k + 1) % poly.size());
      L.minX = min(L.minX, a.x); L.maxX = max(L.maxX, a.x);
      L.minY = min(L.minY, a.y); L.maxY = max(L.maxY, a.y);
      area2 += a.x * b.y - b.x * a.y;
      if (a.y < poly.get(topIdx).y) topIdx = k;
    }
    L.absArea = abs(area2) / 2;

    // Just below the topmost vertex is inside any simple closed curve, so that
    // is a representative interior point. Nudge by a hair of the curve's own
    // height so a tiny loop gets a tiny nudge.
    PVector top = poly.get(topIdx);
    L.rep = new PVector(top.x, top.y + max(1e-4, 0.001 * (L.maxY - L.minY)));
    loops.add(L);
  }

  return loops;
}


// How many curves contain q, found by counting what a ray from q to the right
// crosses. The bounding box test skips almost everything.
int containingCount(ArrayList<Loop> loops, PVector q) {
  int c = 0;
  for (Loop L : loops) {
    if (q.x > L.maxX || q.y < L.minY || q.y > L.maxY) continue;
    ArrayList<PVector> p = L.poly;
    int n = p.size();
    for (int i = 0, j = n - 1; i < n; j = i++) {
      PVector a = p.get(i), b = p.get(j);
      if ((a.y > q.y) != (b.y > q.y)) {
        float xInt = a.x + (q.y - a.y) / (b.y - a.y) * (b.x - a.x);
        if (xInt > q.x) c++;
      }
    }
  }
  return c;
}


void drawTwoColoring(float gridL) {
  ArrayList<Loop> loops = buildLoops(gridL);

  // A curve's interior sits inside itself plus everything around it, so the
  // parity of that count is the colour: odd -> black, even -> white.
  for (Loop L : loops) {
    L.black = (containingCount(loops, L.rep) % 2) == 1;
  }

  // Outermost first. Curves never overlap, so a containing curve always has the
  // larger area -- sorting by area alone puts every parent before its children,
  // and each child then repaints its own interior in the opposite colour.
  Collections.sort(loops, new Comparator<Loop>() {
    public int compare(Loop a, Loop b) { return Float.compare(b.absArea, a.absArea); }
  });

  noStroke();
  for (Loop L : loops) {
    fill(L.black ? 0 : 255);
    beginShape();
    for (PVector p : L.poly) vertex(p.x, p.y);
    endShape(CLOSE);
  }

  int blacks = 0;
  for (Loop L : loops) {
    if (L.black) blacks++;
  }
  println("twoColoring: " + loops.size() + " closed curves, " + blacks + " filled black");
}


void setup() {
  size(1000, 1000);
  pixelDensity(1);

  beginRecord(SVG, "testoutp.svg");

  background(255);
  noFill();

  float gridL = width / (float)gridN;

  // Points are filed per grid-line SEGMENT, not per cell. Each segment is the
  // shared border of exactly two cells and both of them read the same list, so
  // thinning a segment removes the same points from both at once.
  //
  //   vSeg[gx][gy]: vertical line x = gx*gridL, within row gy
  //                 -> cell (gx-1, gy) RIGHT, cell (gx, gy) LEFT
  //   hSeg[gx][gy]: horizontal line y = gy*gridL, within column gx
  //                 -> cell (gx, gy-1) BOTTOM, cell (gx, gy) TOP
  //
  // Index 0 and index gridN stay empty -- those are the outer border of the
  // image, which no scribble crossing ever lands on.
  ArrayList<PVector>[][] vSeg = new ArrayList[gridN + 1][gridN + 1];
  ArrayList<PVector>[][] hSeg = new ArrayList[gridN + 1][gridN + 1];
  for (int a = 0; a <= gridN; a++) {
    for (int b = 0; b <= gridN; b++) {
      vSeg[a][b] = new ArrayList<PVector>();
      hSeg[a][b] = new ArrayList<PVector>();
    }
  }

  if (debugGrid) {
    for (int i = 1; i < gridN; i++) {
      line(0, i * gridL, height, i * gridL);
    }
    for (int i = 1; i < gridN; i++) {
      line(i * gridL, 0, i * gridL, width);
    }
  }

  // one closed random scribble; never drawn
  for (int i = 0; i <= scribbleLen; i++) {
    vList.add(new PVector(random(width), random(height)));
  }
  vList.add(vList.get(0));

  // file every crossing of a grid line onto that line's segment
  for (int i = 0; i < vList.size() - 1; i++) {
    float x1 = vList.get(i).x;
    float y1 = vList.get(i).y;
    float x2 = vList.get(i + 1).x;
    float y2 = vList.get(i + 1).y;

    float s = findSlope(x1, y1, x2, y2);

    float yPos, xPos;

    // vertical grid lines, left to right
    for (float j = (x1 - (x1 % gridL)) + gridL; j <= (x2 - (x2 % gridL)); j += gridL) {
      yPos = y1 + (j - x1) * s;
      vSeg[(int)(j / gridL)][(int)(yPos / gridL)].add(new PVector(j, yPos));
    }

    // vertical grid lines, right to left
    for (float j = (x2 - (x2 % gridL)) + gridL; j <= (x1 - (x1 % gridL)); j += gridL) {
      yPos = y1 + (j - x1) * s;
      vSeg[(int)(j / gridL)][(int)(yPos / gridL)].add(new PVector(j, yPos));
    }

    // horizontal grid lines, top to bottom
    for (float j = (y1 - (y1 % gridL)) + gridL; j <= (y2 - (y2 % gridL)); j += gridL) {
      xPos = x1 + (j - y1) / s;
      hSeg[(int)(xPos / gridL)][(int)(j / gridL)].add(new PVector(xPos, j));
    }

    // horizontal grid lines, bottom to top
    for (float j = (y2 - (y2 % gridL)) + gridL; j <= (y1 - (y1 % gridL)); j += gridL) {
      xPos = x1 + (j - y1) / s;
      hSeg[(int)(xPos / gridL)][(int)(j / gridL)].add(new PVector(xPos, j));
    }
  }

  // sort each segment along its own axis, then thin it to honour lineSep
  Comparator<PVector> byX = new Comparator<PVector>() {
    public int compare(PVector p1, PVector p2) { return Float.compare(p1.x, p2.x); }
  };
  Comparator<PVector> byY = new Comparator<PVector>() {
    public int compare(PVector p1, PVector p2) { return Float.compare(p1.y, p2.y); }
  };

  for (int gx = 1; gx < gridN; gx++) {
    for (int gy = 0; gy < gridN; gy++) {
      Collections.sort(vSeg[gx][gy], byY);
      nPointsDropped += thinEdge(vSeg[gx][gy], true, lineSep,
                                 gy * gridL, (gy + 1) * gridL);
    }
  }
  for (int gx = 0; gx < gridN; gx++) {
    for (int gy = 1; gy < gridN; gy++) {
      Collections.sort(hSeg[gx][gy], byX);
      nPointsDropped += thinEdge(hSeg[gx][gy], false, lineSep,
                                 gx * gridL, (gx + 1) * gridL);
    }
  }

  // hand each cell the four segment lists it borders; both cells sharing a
  // segment alias the same list, which is what kept the thinning consistent
  for (int y = 0; y < gridN; y++) {
    iArr.add(new ArrayList<ArrayList<ArrayList<PVector>>>());
    for (int x = 0; x < gridN; x++) {
      ArrayList<ArrayList<PVector>> cell = new ArrayList<ArrayList<PVector>>();
      cell.add(hSeg[x][y]);      // TOP
      cell.add(vSeg[x + 1][y]);  // RIGHT
      cell.add(hSeg[x][y + 1]);  // BOTTOM
      cell.add(vSeg[x][y]);      // LEFT
      iArr.get(y).add(cell);
    }
  }

  // pair and draw, one cell at a time
  for (int y = 0; y < gridN; y++) {
    for (int x = 0; x < gridN; x++) {
      ArrayList<ArrayList<PVector>> cell = iArr.get(y).get(x);

      int total = 0;
      int[] lo = new int[4];
      int[] hi = new int[4];
      for (int e = 0; e < 4; e++) {
        lo[e] = 0;
        hi[e] = cell.get(e).size() - 1;
        total += cell.get(e).size();
      }
      if (total % 2 == 1) {
        nOddCells++;
        println("cell (" + x + ", " + y + ") has an odd point count: " + total);
      }

      ArrayList<PVector[]> pairs = connectCorners(cell, lo, hi, gridL, x, y);
      nCornerPairs += pairs.size();

      ArrayList<PVector> leftover = leftoverInCyclicOrder(cell, lo, hi);
      if (leftover.size() > 0) nCellsWithLeftover++;
      ArrayList<PVector[]> rest = connectPts(leftover);
      nLeftoverPairs += rest.size();
      pairs.addAll(rest);

      for (int i = 0; i < pairs.size(); i++) {
        if (twoColoring) {
          // defer: the fills have to be painted outermost first, which is not
          // the order the cells come in
          allPairs.add(pairs.get(i));
          allPairCells.add(new int[] { x, y });
        } else {
          drawPair(gridL, x, y, pairs.get(i)[0], pairs.get(i)[1]);
        }
      }
    }
  }

  if (twoColoring) drawTwoColoring(gridL);

  endRecord();

  int totalPairs = nCornerPairs + nLeftoverPairs;
  println("pairs: " + totalPairs
        + "  corner: " + nCornerPairs
        + "  leftover: " + nLeftoverPairs
        + "  (" + nf((float)(100.0 * nLeftoverPairs / max(1, totalPairs)), 0, 1) + "% free)");
  println("cells with any leftover: " + nCellsWithLeftover + " / " + (gridN * gridN));
  println("points dropped for lineSep=" + lineSep + ": " + nPointsDropped
        + "  (" + nSacrificed + " segments needed a parity sacrifice)");
  if (nForcedKeeps > 0) {
    println(nForcedKeeps + " segments held an odd point count the sweep wanted to"
          + " empty, so one mark stayed inside lineSep to hold parity");
  }
  if (nOddCells > 0) println("WARNING: " + nOddCells + " cells had an odd point count");
}
