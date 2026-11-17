// Builds the STEP preview sample: a small Benchy-style tugboat made of separate solids
// (hull, deck, cabin, roof, chimney, bollards, rail posts), so the "Parts to show" limit has something to cut.
// Needs OpenCASCADE (brew install opencascade). Run:
//   P=/opt/homebrew/opt/opencascade
//   clang++ -w -std=c++17 -O2 Tools/make-benchy-step.cpp -I$P/include/opencascade -L$P/lib -Wl,-rpath,$P/lib \
//     $(ls $P/lib | grep '^libTK.*dylib$' | grep -v '\..*\..*dylib' | sed 's/^lib/-l/;s/\.dylib//') -o /tmp/make-benchy-step
//   /tmp/make-benchy-step Sources/STLerApp/Resources/3DBenchy.step
#include <BRep_Builder.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <STEPControl_Writer.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <gp_Ax2.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <cstdio>

static TopoDS_Shape box(double x, double y, double z, double dx, double dy, double dz) {
    return BRepPrimAPI_MakeBox(gp_Pnt(x, y, z), dx, dy, dz).Shape();
}

static TopoDS_Shape cylinder(double x, double y, double z, double radius, double height) {
    return BRepPrimAPI_MakeCylinder(gp_Ax2(gp_Pnt(x, y, z), gp_Dir(0, 0, 1)), radius, height).Shape();
}

int main(int argc, char** argv) {
    // Hull: side profile (x forward, z up) with a raked bow, extruded across the beam, bottom edges rounded.
    BRepBuilderAPI_MakePolygon side;
    for (auto p : {gp_Pnt(-28, -14, 4), gp_Pnt(-24, -14, 0), gp_Pnt(18, -14, 0), gp_Pnt(30, -14, 10), gp_Pnt(30, -14, 15), gp_Pnt(-28, -14, 15)}) side.Add(p);
    side.Close();
    TopoDS_Shape hull = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(side.Wire()).Face(), gp_Vec(0, 28, 0)).Shape();
    BRepFilletAPI_MakeFillet fillet(hull);
    for (TopExp_Explorer edges(hull, TopAbs_EDGE); edges.More(); edges.Next()) fillet.Add(2.5, TopoDS::Edge(edges.Current()));
    fillet.Build();
    if (fillet.IsDone()) hull = fillet.Shape();

    TopoDS_Shape deck = box(-27, -13, 15, 56, 26, 1.5);

    // Cabin with a window cut through each wall.
    TopoDS_Shape cabin = box(-4, -9, 16.5, 20, 18, 17);
    for (auto window : {box(-1, -10, 22, 6, 20, 7), box(8, -10, 22, 6, 20, 7), box(14, -5, 22, 3, 10, 7)}) cabin = BRepAlgoAPI_Cut(cabin, window).Shape();

    TopoDS_Shape roof = box(-6, -11, 33.5, 24, 22, 2);

    // Chimney: a tube standing on the roof.
    TopoDS_Shape chimney = BRepAlgoAPI_Cut(cylinder(4, 0, 35.5, 4, 12.5), cylinder(4, 0, 38, 2.4, 10)).Shape();

    TopoDS_Compound boat;
    BRep_Builder builder;
    builder.MakeCompound(boat);
    for (auto part : {hull, deck, cabin, roof, chimney}) builder.Add(boat, part);
    for (double x : {22.0, 26.0}) for (double y : {-12.0, 12.0}) builder.Add(boat, cylinder(x, y, 16.5, 0.8, 5));
    builder.Add(boat, cylinder(-24, 0, 16.5, 2.2, 3));
    builder.Add(boat, cylinder(-24, 0, 19.5, 1.4, 4));

    STEPControl_Writer writer;
    writer.Transfer(boat, STEPControl_AsIs);
    if (writer.Write(argc > 1 ? argv[1] : "3DBenchy.step") != IFSelect_RetDone) { std::fprintf(stderr, "write failed\n"); return 1; }
    return 0;
}
