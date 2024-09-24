require "spec"
require "../src/recursivegrid"

describe RecursiveGrid do
    it "simple row" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10,20]])
        grid.size.should eq({1, 2})
        grid.get_matrix.should eq([[10, 20]])
    end
    it "simple column" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10],[20]])
        grid.size.should eq({2, 1})
        grid.get_matrix.should eq([[10], [20]])
    end
    it "simple 2x2 matrix" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10,20],[30,40]])
        grid.size.should eq({2, 2})
        grid.get_matrix.should eq([
            [10, 20],
            [30, 40]
        ])
    end
    it "simple recursion doesn't change result" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[c.new([[10,20],[30,40]])]])
        grid.size.should eq({2, 2})
        grid.get_matrix.should eq([
            [10, 20],
            [30, 40]
        ])
    end
    it "checking #elements in simple use case" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10,20],[30,40]])
        arr = Array(Tuple(Int32, Tuple(Int32,Int32), Tuple(Int32,Int32))).new
        grid.elements {|el| arr << el[0..2]} # we ignore local_grid and local_index
        arr.should eq([
            {10, {0,0}, {0,0}},
            {20, {0,1}, {0,1}},
            {30, {1,0}, {1,0}},
            {40, {1,1}, {1,1}}
        ])
    end
    it "simple nesting and spanning, variant 1" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10, c.new([[20],[30]])]])
        grid.size.should eq({2, 2})
        grid.get_matrix.should eq([
            [10, 20],
            [10, 30]
        ])
        grid.inspect.should eq ("Grid([[10, Grid([[20], [30]])]])")
        arr = Array(Tuple(Int32, Tuple(Int32,Int32), Tuple(Int32,Int32))).new
        grid.grids {|level,g,bmin,bmax| arr << {level, bmin, bmax}} # we drop Grid
        arr.should eq([
            { 0, {0,0}, {1,1}},
            { 1, {0,1}, {1,1}}
        ])
    end
    it "three levels" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10, c.new([[20, c.new([[30]])]])]])
        grid.size.should eq({1, 3})
        grid.get_matrix.should eq([
            [10, 20, 30]
        ])
        grid.inspect.should eq ("Grid([[10, Grid([[20, Grid([[30]])]])]])")
        arr = Array(Tuple(Int32, Tuple(Int32,Int32), Tuple(Int32,Int32))).new
        grid.grids {|level,g,bmin,bmax| arr << {level, bmin, bmax}} # we drop Grid
        arr.should eq([
            { 0, {0,0}, {0,2}},
            { 1, {0,1}, {0,2}},
            { 2, {0,2}, {0,2}}
        ])
    end
    it "simple nesting and spanning, variant 2" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[c.new([[10]]), c.new([[20],[30]])]])
        grid.size.should eq({2, 2})
        grid.get_matrix.should eq([
            [10, 20],
            [10, 30]
        ])
    end
    it "disable spanning" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[c.new([[10],[c.new]]), c.new([[20],[30],[40]])]])
        # since we always span the last row/column, an empty RecursiveGrid can be used to effectively stop spanning
        grid.size.should eq({3, 2})
        grid.get_matrix.should eq([
            [10 , 20],
            [nil, 30],
            [nil, 40]
        ])
    end
    it "unbalanced spanning" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[c.new([[10],[20],[30]]), c.new([[40]]), c.new([[50],[60]])]])
        grid.size.should eq({3, 3})
        grid.get_matrix.should eq([
            [10, 40, 50],
            [20, 40, 60],
            [30, 40, 60] # the last element (60 here) always gets spanned
        ])
    end
    it "spanning in two dimensions" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([
            [c.new([[10    ]]), c.new([[20],[30]])],
            [c.new([[40, 50]]), c.new             ]
        ])
        grid.size.should eq({3, 3})
        grid.get_matrix.should eq([
            [10, 10, 20 ],
            [10, 10, 30 ],
            [40, 50, nil]
        ])
    end
    it "late changes" do
        c = RecursiveGrid::Grid(Int32)
        subgrid = c.new([[20],[30]])
        grid = c.new([[10, subgrid]])
        grid.size.should eq({2, 2})
        grid.get_matrix.should eq([
            [10, 20],
            [10, 30]
        ])
        grid.replace {|m| m[0][0] = 90; m}
        grid.get_matrix.should eq([
            [90, 20],
            [90, 30]
        ])
        subgrid.replace {|m| [[20,30],[40,50]]}
        grid.get_matrix.should eq([
            [90, 20, 30],
            [90, 40, 50]
        ])
    end
    it "bug introduced in 6881d20f03e5e333027cb1e9c955df158dd87b06" do
        c = RecursiveGrid::Grid(Int32)
        grid = c.new([[10, 20], [30, c.new([[40, 50]])]])
        grid.get_matrix.should eq([
            [10, 20, 20],
            [30, 40, 50]
        ])
    end
end
