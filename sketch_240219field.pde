import processing.svg.*;
import java.util.Collections;
import java.util.Comparator;

int gridN = 8;
int  scribbleLen = 200;
boolean debugGrid = false;

ArrayList<PVector> vList = new ArrayList<PVector>();
ArrayList<PVector> iList = new ArrayList<PVector>();
ArrayList<ArrayList<ArrayList<ArrayList<PVector>>>> iArr = new ArrayList<ArrayList<ArrayList<ArrayList<PVector>>>>();
PVector centroid = new PVector();

float findSlope(float x1, float y1, float x2, float y2) {
  return (y2 - y1) / (x2 - x1);
}

float angleSort(PVector p1, PVector p2) {
  double angleA = Math.atan2(p1.y - centroid.y, p1.x - centroid.x);
  double angleB = Math.atan2(p2.y - centroid.y, p2.x - centroid.x);
  return (float)(angleA - angleB);
}


ArrayList<PVector[]> connectPts(ArrayList<PVector> arr, ArrayList<PVector[]> lineArr) {
  if (arr.size() == 0) {
    return lineArr;
  } else if (arr.size() == 2) {
    // println(arr.get(0).x + ", " + arr.get(1).x);
    lineArr.add(new PVector[] { arr.get(0), arr.get(1) });
    return lineArr;
  } else {
    int p1 = int(random(0, arr.size()));
    int p2 = (p1 + 1 + 2 * int(random(0, arr.size() / 2))) % arr.size();
    lineArr.add(new PVector[] { arr.get(p1), arr.get(p2) });
    // println(arr.get(p1).x + ", " + arr.get(p2).x);

    ArrayList<PVector> arr1, arr2;
    if (p1 < p2) {
      arr1 = new ArrayList<PVector>(arr.subList(p1 + 1, p2));
      arr2 = new ArrayList<PVector>();
      arr2.addAll(arr.subList(p2 + 1, arr.size()));
      arr2.addAll(arr.subList(0, p1));
    } else {
      if(arr.size()%2 == 1) {
        println(arr.size());
      }
      if(p1 == p2) {
        println(p1, p2, arr);
      }
      arr1 = new ArrayList<PVector>(arr.subList(p2 + 1, p1));
      arr2 = new ArrayList<PVector>();
      arr2.addAll(arr.subList(p1 + 1, arr.size()));
      arr2.addAll(arr.subList(0, p2));
    }

    ArrayList<PVector[]> retarr1 = connectPts(arr1, lineArr);
    ArrayList<PVector[]> retarr2 = connectPts(arr2, lineArr);
    return lineArr;
  }
}

void setup() {
  size(1600, 1600);
  
  beginRecord(SVG, "testoutp.svg");
  
  background(255);
  noFill();
  
  float gridL = width / (float)gridN;
  
  for (int y = 0; y < gridN; y++) {
    iArr.add(new ArrayList<ArrayList<ArrayList<PVector>>>());
    for (int x = 0; x < gridN; x++) {
      iArr.get(y).add(new ArrayList<ArrayList<PVector>>());
      for (int i = 0; i < 5; i++) {
        iArr.get(y).get(x).add(new ArrayList<PVector>());
      }
    }
  }
  
  if(debugGrid) {
    for(int i = 1; i< gridN; i++) {
      line(0, i*gridL, height, i*gridL);
    }
    for(int i = 1; i< gridN; i++) {
      line(i*gridL, 0, i*gridL, width);
    }
  }
  
  for (int i = 0; i <= scribbleLen; i++) {
    vList.add(new PVector(random(width), random(height)));
  }
  vList.add(vList.get(0));
  
  //beginShape();
  //for(int i = 0; i < vList.size(); i++) {
  //  vertex(vList.get(i).x, vList.get(i).y);
  //}
  //endShape();
  
  for (int i = 0; i < vList.size() - 1; i++) {
    float x1 = vList.get(i).x;
    float y1 = vList.get(i).y;
    float x2 = vList.get(i + 1).x;
    float y2 = vList.get(i + 1).y;
    
    float s = findSlope(x1, y1, x2, y2);
    
    float yPos, xPos;

    // First loop
    for (float j = (x1 - (x1 % gridL)) + gridL; j <= (x2 - (x2 % gridL)); j += gridL) {
        yPos = y1 + (j - x1) * s;
        PVector point = new PVector(j, yPos);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL)).get(3).add(point);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL) - 1).get(1).add(point);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL)).get(4).add(point);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL) - 1).get(4).add(point);
    }
    
    // Second loop - Note the conditions in the loop may need to be adjusted depending on the specific logic of traversal
    for (float j = (x2 - (x2 % gridL)) + gridL; j <= (x1 - (x1 % gridL)); j += gridL) {
        yPos = y1 + (j - x1) * s;
        PVector point = new PVector(j, yPos);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL)).get(3).add(point);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL) - 1).get(1).add(point);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL)).get(4).add(point);
        iArr.get((int)(yPos / gridL)).get((int)(j / gridL) - 1).get(4).add(point);
    }
    
    // Third loop
    for (float j = (y1 - (y1 % gridL)) + gridL; j <= (y2 - (y2 % gridL)); j += gridL) {
        xPos = x1 + (j - y1) / s;
        PVector point = new PVector(xPos, j);
        iArr.get((int)(j / gridL)).get((int)(xPos / gridL)).get(0).add(point);
        iArr.get((int)(j / gridL) - 1).get((int)(xPos / gridL)).get(2).add(point);
        iArr.get((int)(j / gridL)).get((int)(xPos / gridL)).get(4).add(point);
        iArr.get((int)(j / gridL) - 1).get((int)(xPos / gridL)).get(4).add(point);
    }
    
    // Fourth loop
    for (float j = (y2 - (y2 % gridL)) + gridL; j <= (y1 - (y1 % gridL)); j += gridL) {
        xPos = x1 + (j - y1) / s;
        PVector point = new PVector(xPos, j);
        iArr.get((int)(j / gridL)).get((int)(xPos / gridL)).get(0).add(point);
        iArr.get((int)(j / gridL) - 1).get((int)(xPos / gridL)).get(2).add(point);
        iArr.get((int)(j / gridL)).get((int)(xPos / gridL)).get(4).add(point);
        iArr.get((int)(j / gridL) - 1).get((int)(xPos / gridL)).get(4).add(point);
    }

    
  }
  
  
  //MIGHT BE WRONG
  for (int y = 0; y < gridN; y++) {
    for (int x = 0; x < gridN; x++) {
        centroid = new PVector(x * gridL + gridL / 2, y * gridL + gridL / 2);
        
        if(iArr.get(y).get(x).get(4).size() % 2 == 1) {
          println("before sort: ", iArr.get(y).get(x).get(4));
        }

        // Sort the ArrayList<PVector> based on angle to centroid
        Collections.sort(iArr.get(y).get(x).get(4), new Comparator<PVector>() {
            public int compare(PVector p1, PVector p2) {
                float angle1 = PVector.sub(p1, centroid).heading();
                float angle2 = PVector.sub(p2, centroid).heading();
                return Float.compare(angle1, angle2);
            }
        });
        
    }
  }
  
  ArrayList<PVector[]> lineArr;

  for (int y = 0; y < gridN; y++) {
      for (int x = 0; x < gridN; x++) {
          
          lineArr = connectPts(iArr.get(y).get(x).get(4), new ArrayList<PVector[]>());
          
          for (int i = 0; i < lineArr.size(); i++) {
              PVector p1 = lineArr.get(i)[0];
              PVector p2 = lineArr.get(i)[1];
              
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
              
              if (x1 == x2) {
                  startAng = x1 == x * gridL ? (3 * PI) / 2 : PI / 2;
                  arc(x1, (y1 + y2) / 2, abs(y1 - y2), abs(y1 - y2), startAng, startAng + PI);
              } else if (y1 == y2) {
                  startAng = y1 == y * gridL ? 0 : PI;
                  arc((x1 + x2) / 2, y1, abs(x1 - x2), abs(x1 - x2), startAng, startAng + PI);
              } else if (abs(x1 - x2) == gridL) {
                  float s = (y2 - y1) / (x2 - x1);
                  if (s > 0) {
                      arc(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI);
                      arc(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2*PI);
                  } else if (s == 0) {
                      line(x1, y1, x2, y2);
                  } else {
                      arc(x1, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2);
                      arc(x2, (y1 + y2) / 2, abs(x1 - x2), abs(y1 - y2), 0, PI / 2);
                  }
              } else if (abs(y1 - y2) == gridL) {
                  float s = (y2 - y1) / (x2 - x1);
                  if (s > 0) {
                      arc((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI / 2, PI);
                      arc((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), (3 * PI) / 2, 2*PI);
                  } else if (s == 0) {
                      line(x1, y1, x2, y2);
                  } else {
                      arc((x1 + x2) / 2, y2, abs(x1 - x2), abs(y1 - y2), PI, (3 * PI) / 2);
                      arc((x1 + x2) / 2, y1, abs(x1 - x2), abs(y1 - y2), 0, PI / 2);
                  }
              } else {
                  if (y1 < y2) {
                      if (y * gridL == y1) {
                          arc(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), 0, PI / 2);
                      } else {
                          arc(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI, (3 * PI) / 2);
                      }
                  } else {
                      if ((y + 1) * gridL == y1) {
                          arc(x2, y1, 2 * abs(x2 - x1), 2 * abs(y2 - y1), (3 * PI) / 2, 2*PI);
                      } else {
                          arc(x1, y2, 2 * abs(x2 - x1), 2 * abs(y2 - y1), PI / 2, PI);
                      }
                  }
              }
          }
      }
  }
  
  
  
  
  endRecord();
  
}
