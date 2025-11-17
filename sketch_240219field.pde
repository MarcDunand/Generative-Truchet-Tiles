import processing.svg.*;
import java.util.Collections;
import java.util.Comparator;
import java.util.*;


public static final class EllipseAA {
  public final float cx, cy;   // center
  public final float a, b;     // semi-axes (a = radius on x, b = radius on y)
  public final float i, f;     // start and end angles (radians)

  public final PVector start;
  public final PVector end;

  public EllipseAA(float cx, float cy, float a, float b, float i, float f) {
    this.cx = cx;
    this.cy = cy;
    this.a  = a;
    this.b  = b;
    this.i  = i;
    this.f  = f;

    // Calculate start point (based on i)
    this.start = new PVector(cx + (a/2) * (float)Math.cos(i), cy + (b/2) * (float)Math.sin(i));

    // Calculate end point (based on f)
    this.end = new PVector(cx + (a/2) * (float)Math.cos(f), cy + (b/2) * (float)Math.sin(f));
  }
}


//debug
float fails = 0.0;


int gridN = 10;
int iters = 200;
int maxAttempts = 3;
double lineSep = 2;
boolean debugGrid = false;

PVector centroid = new PVector();


float findSlope(float x1, float y1, float x2, float y2) {
  return (y2 - y1) / (x2 - x1);
}

float angleSort(PVector p1, PVector p2) {
  double angleA = Math.atan2(p1.y - centroid.y, p1.x - centroid.x);
  double angleB = Math.atan2(p2.y - centroid.y, p2.x - centroid.x);
  return (float)(angleA - angleB);
}

void drawArc(EllipseAA e) {
  float w = (float)(e.a);
  float h = (float)(e.b);
  float x = (float)e.cx;
  float y = (float)e.cy;
  float i = (float)e.i;
  float f = (float)e.f;
  arc(x, y, w, h, i, f);
}

PVector randomGridStep(PVector cur) {
  // Possible directions (x,y)
  int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
  
  // Collect valid moves
  ArrayList<PVector> validMoves = new ArrayList<PVector>();
  for (int[] d : dirs) {
    int nx = int(cur.x) + d[0];
    int ny = int(cur.y) + d[1];
    if (nx >= 0 && nx < gridN && ny >= 0 && ny < gridN) {
      validMoves.add(new PVector(nx, ny));
    }
  }
  
  // Always at least one valid move (guaranteed inside bounds)
  return validMoves.get(int(random(validMoves.size())));
}


int generateArc(ArrayList<EllipseAA> arcArr, float gridL, PVector cell, PVector p1, PVector p2) {
  int x = int(cell.x);
  int y = int(cell.y);
  
  float x1;
  float y1;
  float x2;
  float y2;
    
  if (p1.x > p2.x) {
      x1 = p1.x;
      y1 = p1.y;
      x2 = p2.x;
      y2 = p2.y;
  } else {
      x2 = p1.x;
      y2 = p1.y;
      x1 = p2.x;
      y1 = p2.y;
  }
  
  float startAng;
  
  if (x1 == x2) {  //side left and right
      startAng = x1 == x * gridL ? (3 * PI) / 2 : PI / 2;
      arcArr.add(new EllipseAA(x1, (y1 + y2) / 2, abs(y1 - y2), abs(y1 - y2), startAng, startAng + PI));
      return 1;
  } else if (y1 == y2) {  //side top and bottom
      startAng = y1 == y * gridL ? 0 : PI;
      arcArr.add(new EllipseAA((x1 + x2) / 2, y1, abs(x1 - x2), abs(x1 - x2), startAng, startAng + PI));
      return 1;
  } else if (abs(x1 - x2) == gridL) {  //cross left and right
      float s = (y2 - y1) / (x2 - x1);
      if (s > 0) {
          arcArr.add(new EllipseAA(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI));
          arcArr.add(new EllipseAA(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2*PI));
          return 2;
      } else if (s == 0) {
          line(x1, y1, x2, y2);
          return 0;
      } else {
          arcArr.add(new EllipseAA(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2));
          arcArr.add(new EllipseAA(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), 0, PI / 2));
          return 2;
      }
  } else if (abs(y1 - y2) == gridL) {  //cross top and bottom
      float s = (y2 - y1) / (x2 - x1);
      if (s > 0) {
          arcArr.add(new EllipseAA((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI));
          arcArr.add(new EllipseAA((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2*PI));
          return 2;
      } else if (s == 0) {
          line(x1, y1, x2, y2);
          return 0;
      } else {
          arcArr.add(new EllipseAA((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2));
          arcArr.add(new EllipseAA((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), 0, PI / 2));
          return 2;
      }
  } else {  //corner
      if (y1 < y2) {
          if (y * gridL == y1) {
              arcArr.add(new EllipseAA(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), 0, PI / 2));
              return 1;
          } else {
              arcArr.add(new EllipseAA(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI, (3 * PI) / 2));
              return 1;
          }
      } else {
          if ((y + 1) * gridL == y1) {
              arcArr.add(new EllipseAA(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), (3 * PI) / 2, 2*PI));
              return 1;
          } else {
              arcArr.add(new EllipseAA(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI / 2, PI));
              return 1;
          }
      }
  }
}

//working on trying to never double check the same wiring within a given tile
//int[] connectPtsSeed(ArrayList<Integer> arr) {
//  int arrLen = arr.size();
//  int steps = arrLen/2;
//  int[] choices = new int[steps];
//  choices[0] = int(random(arrLen));
//  choices[1] = int(random(steps));
  
//  return choices;
//}


ArrayList<int[]> connectPts(ArrayList<Integer> arr, ArrayList<Integer> lineArr) {
  if (arr.size() == 0) {
    return lineArr;
  } else if (arr.size() == 2) {
    lineArr.add(arr.get(0));
    lineArr.add(arr.get(1));
    return lineArr;
  } else {
    int p1 = int(random(0, arr.size()));
    int p2 = (p1 + 1 + 2 * int(random(0, arr.size() / 2))) % arr.size();
    lineArr.add(arr.get(p1));
    lineArr.add(arr.get(p2));
    // println(arr.get(p1).x + ", " + arr.get(p2).x);

    ArrayList<Integer> arr1, arr2;
    if (p1 < p2) {
      arr1 = new ArrayList<Integer>(arr.subList(p1 + 1, p2));
      arr2 = new ArrayList<Integer>();
      arr2.addAll(arr.subList(p2 + 1, arr.size()));
      arr2.addAll(arr.subList(0, p1));
    } else {
      if(arr.size()%2 == 1) {
        println(arr.size());
      }
      if(p1 == p2) {
        println(p1, p2, arr);
      }
      arr1 = new ArrayList<Integer>(arr.subList(p2 + 1, p1));
      arr2 = new ArrayList<Integer>();
      arr2.addAll(arr.subList(p1 + 1, arr.size()));
      arr2.addAll(arr.subList(0, p2));
    }

    ArrayList<Integer> retarr1 = connectPts(arr1, lineArr);
    ArrayList<Integer> retarr2 = connectPts(arr2, lineArr);
    return lineArr;
  }
}


void setup() {
  size(800, 800);
  
  beginRecord(SVG, "testoutp.svg");
  
  background(255);
  noFill();
  
  float gridL = width / (float)gridN;
  
  PVector curCell = new PVector(0, 0);
  PVector curPos = new PVector(gridL, gridL/2);
  PVector nextCell = new PVector(-1, -1);
  PVector nextPos = new PVector(-1, -1);
  
  ArrayList<EllipseAA>[][] arcArrList = new ArrayList[gridN][gridN];  //create and initialize the arc data struct (2D array of arraylists of arcs)
  for(int x = 0; x < gridN; x++){
    for(int y = 0; y < gridN; y++){
      arcArrList[y][x] = new ArrayList<EllipseAA>();
    }
  }
    
  
  for (int i = 0; i < iters; i++) {
    ArrayList<EllipseAA> arcCell = arcArrList[int(curCell.x)][int(curCell.y)];
    boolean intersects = true;
    int attempts = 0;
    
    Set<List<Integer>> invalidWiringSet = new HashSet<>();
    
    while(intersects && attempts < maxAttempts) {
      nextCell = randomGridStep(curCell);
      nextPos.x = nextCell.x*gridL;
      nextPos.y = nextCell.y*gridL;
      if(nextCell.x == curCell.x) {  //vertical cell change
        nextPos.x = nextCell.x*gridL + int(random(gridL));
        if(nextCell.y > curCell.y) {  //cell went down
          nextPos.y = nextCell.y*gridL;
        }
        else {  //cell went up
          nextPos.y = (nextCell.y+1)*gridL;
        }
      }
      else {  //horizontal cell change
         nextPos.y = nextCell.y*gridL + int(random(gridL));
        if(nextCell.x > curCell.x) {  //cell went down
          nextPos.x = nextCell.x*gridL;
        }
        else {  //cell went up
          nextPos.x = (nextCell.x+1)*gridL;
        }   
        
      }
    
      intersects = false;
      int numArcs = generateArc(arcCell, gridL, curCell, curPos, nextPos);
      
      EllipseAA Arc1 = arcCell.get(arcCell.size()-1);
      for(int j = 0; j < arcCell.size()-numArcs; j++) {
        EllipseAA Arc2 = arcCell.get(j);
        if(arcsTooClosePseudo(Arc1, Arc2, lineSep, 1440, 1e-8)) {
          intersects = true;
        }
      }
      
      if(numArcs == 2) {
        Arc1 = arcCell.get(arcCell.size()-2);
        for(int j = 0; j < arcCell.size()-numArcs; j++) {
          EllipseAA Arc2 = arcCell.get(j);
          if(arcsTooClosePseudo(Arc1, Arc2, lineSep, 1440, 1e-8)) {
            intersects = true;
          }
        }
      }
      
      if(intersects) {
        attempts++;
        arcCell.remove(arcCell.size()-1);
        fails++;
        if(numArcs == 2) {
          arcCell.remove(arcCell.size()-1);
          fails++;
        }
      }
    }
    
    if(attempts == maxAttempts) {  //if failed to find a next arc
    
      //find all cell inters
      ArrayList<PVector> cellInters = new ArrayList<PVector>();
      for(int j = 0; j < arcCell.size(); j++) {
        cellInters.add(arcCell.get(j).start);
        cellInters.add(arcCell.get(j).end);
      }
      cellInters.add(curPos);
             

      // Sort the ArrayList<PVector> based on angle to centroid
      PVector centroid = new PVector(curCell.x*gridL + gridL / 2, curCell.y*gridL + gridL / 2);

      Collections.sort(cellInters, new Comparator<PVector>() {
          public int compare(PVector p1, PVector p2) {
              float angle1 = PVector.sub(p1, centroid).heading();
              float angle2 = PVector.sub(p2, centroid).heading();
              return Float.compare(angle1, angle2);
          }
      });
      
      int newStartIdx = 0;
      ArrayList<Integer> interPairsEmpty = new ArrayList<Integer>();
      ArrayList<Integer> interIdxs = new ArrayList<Integer>();
      
      boolean anyIntersects = true;
      while(anyIntersects) {
        anyIntersects = false;
        
        interPairsEmpty.clear();
        interIdxs.clear();
        
        for(int j = 0; j < cellInters.size(); j++) {
          interIdxs.add(j);
        }
        newStartIdx = int(random(interIdxs.size()));
        interIdxs.remove(newStartIdx);
        
        boolean alreadyAttempted = true;
        
        while(alreadyAttempted) {
          ArrayList<Integer> interPairIdxs = connectPts(interIdxs, interPairsEmpty);
          invalidWiringSet.add(interPairIdxs);
        }

        arcCell.clear();
        for(int j = 0; j < interPairIdxs.size(); j++) {
          generateArc(arcCell, gridL, curCell, cellInters.get(interPairIdxs.get(j)[0]), cellInters.get(interPairIdxs.get(j)[1]));
        }
        
        int j = 0;
        while(j < arcCell.size() && !anyIntersects) {
          int k = j+1;
          while(k < arcCell.size() && !anyIntersects) {
            if(arcsTooClosePseudo(arcCell.get(j), arcCell.get(k), lineSep, 1440, 1e-8)) {
              anyIntersects = true;
            }
            k++;
          }
          j++;
        }
      }
      
      
      curPos.x = cellInters.get(newStartIdx).x;
      curPos.y = cellInters.get(newStartIdx).y;
      
      

      
      
      
      
      
      
      
      //curCell.x = int(random(gridN)); curCell.y = int(random(gridN));
      //if(random(1) < 0.5) {
      //  curPos.x = curCell.x*gridL+int(random(gridL));
      //  curPos.y = curCell.y*gridL+int(random(2))*gridL;
      //}
      //else{
      //  curPos.y = curCell.y*gridL+int(random(gridL));
      //  curPos.x = curCell.x*gridL+int(random(2))*gridL;
      //}
    }
    else {
      curCell.x = nextCell.x; curCell.y = nextCell.y;
      curPos.x = nextPos.x; curPos.y = nextPos.y;
    }
    print(i, " ");
  }
  
  
  //Draw all arcs at the end
  for(int x = 0; x < gridN; x++){
    for(int y = 0; y < gridN; y++){
      ArrayList<EllipseAA> thisCell = arcArrList[y][x];
      for(int i = 0; i < thisCell.size(); i++) {
        drawArc(thisCell.get(i));
      }
    }
  }
  
  endRecord();
  
  println(fails/float(iters));
  
}








private static double[] pointOnEllipseAA_diam(EllipseAA e, double t) {
  double rx = 0.5 * e.a; // radii = diam/2
  double ry = 0.5 * e.b;
  double x = e.cx + rx * Math.cos(t);
  double y = e.cy + ry * Math.sin(t);
  return new double[]{x, y};
}

// --- 1) Pseudo-distance helper (diameters in EllipseAA) ---
private static double approxDistanceToEllipseBoundary_diam(EllipseAA e, double x, double y) {
  double rx = 0.5 * e.a, ry = 0.5 * e.b;
  double dx = x - e.cx, dy = y - e.cy;

  // Implicit value (level set 0 is the ellipse)
  double F = (dx*dx)/(rx*rx) + (dy*dy)/(ry*ry) - 1.0;

  // Gradient norm
  double gx = 2.0 * dx / (rx*rx);
  double gy = 2.0 * dy / (ry*ry);
  double gnorm = Math.hypot(gx, gy);

  // If gradient is (pathologically) zero, return a large distance
  if (gnorm < 1e-12) return Double.POSITIVE_INFINITY;

  return Math.abs(F) / gnorm;
}

// --- 2) Cheap bbox with a D margin for early-out ---
private static boolean bboxCloserThan_diam(EllipseAA e1, EllipseAA e2, double D) {
  double rx1 = 0.5 * e1.a, ry1 = 0.5 * e1.b;
  double rx2 = 0.5 * e2.a, ry2 = 0.5 * e2.b;
  double l1 = e1.cx - rx1 - D, r1 = e1.cx + rx1 + D;
  double t1 = e1.cy - ry1 - D, b1 = e1.cy + ry1 + D;
  double l2 = e2.cx - rx2,     r2 = e2.cx + rx2;
  double t2 = e2.cy - ry2,     b2 = e2.cy + ry2;
  return !(r1 < l2 || r2 < l1 || b1 < t2 || b2 < t1);
}

// --- 3) New proximity checker using pseudo-distance ---
public static boolean arcsTooClosePseudo(EllipseAA A, EllipseAA B,
                                         double D, int samples, double eps) {
  // Early-out: if even the expanded boxes don't touch, they can't be within D
  if (!bboxCloserThan_diam(A, B, D)) return false;

  double[] sA = normSpan(A.i, A.f);
  double[] sB = normSpan(B.i, B.f);

  // Sample arc A and measure distance to ellipse B's boundary
  for (int k = 0; k < samples; k++) {
    double t = sA[0] + (sA[1] - sA[0]) * (k / (double)(samples - 1));
    double[] p = pointOnEllipseAA_diam(A, t);
    double d = approxDistanceToEllipseBoundary_diam(B, p[0], p[1]);
    if (d <= D - eps) return true;
  }

  // Symmetric pass: sample arc B, distance to ellipse A
  for (int k = 0; k < samples; k++) {
    double t = sB[0] + (sB[1] - sB[0]) * (k / (double)(samples - 1));
    double[] p = pointOnEllipseAA_diam(B, t);
    double d = approxDistanceToEllipseBoundary_diam(A, p[0], p[1]);
    if (d <= D - eps) return true;
  }

  return false;
}


// Normalize [i,f] to a forward, monotone interval of length in (0, 2π]
private static double[] normSpan(double i, double f) {
  final double TWO_PI = 2.0 * Math.PI;
  i = i % TWO_PI; if (i < 0) i += TWO_PI;
  f = f % TWO_PI; if (f < 0) f += TWO_PI;
  double len = f - i;
  if (len <= 0) len += TWO_PI;
  return new double[]{ i, i + len }; // monotone [i, i+len]
}
