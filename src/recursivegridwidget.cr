require "./framework"
require "./recursivegrid"

# todos
# - also resize according to spanned cells (see below)
# - get rid of border clipping (see below)
# - define concept to allow center/bottom-aligned painting in a cell

include GUI

module RecursiveGridWidget

abstract class ElementWidget
    abstract def paint : Nil
    def size : ImVec2
        ImGui.get_window_content_region_max
        # ImGui.get_window_size
    end
    def draw_background(color = ImGui.hsv(0.0, 0.0, 0.3, 1.0))
        dl = ImGui.get_window_draw_list
        apos = ImGui.get_window_pos
        dl.add_rect_filled(apos, apos+size, ImGui.get_color_u32(color))
    end
    def draw_boundary(color = ImGui.hsv(0.0, 0.0, 0.3, 1.0)) # tbd this gets clipped
        dl = ImGui.get_window_draw_list
        apos = ImGui.get_window_pos
        dl.add_rect(apos, apos+size, ImGui.get_color_u32(color))
    end
end

class GridWidget
    GRID_COLOR = ImGui.hsv(0.0, 1.0, 1.0, 1.0)
    SUBGRID_SPACER = 5 # px
    ADDER_GENERAL = 4 # px
    # we have three sizes: used (measured, in @feedback_sizes), content and child
    ADDER_CHILD_SIZE = 20 # px, from used to child
    ADDER_CONTENT_SIZE = -10 # px, from child to content
    property draw_grid_frames = false
    # the following two are a bit ugly, but they help mainly for the demo
    getter local_grid = RecursiveGrid::Grid(RecursiveGridWidget::ElementWidget).new
    getter local_index = {0, 0}
    def initialize(@grid : RecursiveGrid::Grid(ElementWidget), @draw_grid_frames = false) # BTW: need to use base class here (ElementWidget)
        @sizes = {Array(Int32).new, Array(Int32).new} # rows, cols; for @grid.elements
        @offsets = {Array(Int32).new, Array(Int32).new} # rows+1, cols+1; for @grid.elements
        @grid_before_sizes = {Array(Int32).new, Array(Int32).new} # rows, cols; used for @grid.grids (i.e. for boundaries, @sizes "+1")
        @grid_after_sizes = {Array(Int32).new, Array(Int32).new} # rows, cols; used for @grid.grids (i.e. for boundaries, @sizes "+1")
        @grid2local_offset = Hash(RecursiveGrid::Grid(ElementWidget), Tuple(ImVec2, ImVec2)).new
        @sizes_feedback = {Array(Int32).new, Array(Int32).new} # rows, cols; feedback loop from GUI
    end
    def paint
        s = @grid.size
        adapt_size(@sizes[0], s[0], 10) # arbitrary magic 10 for initial size
        adapt_size(@sizes[1], s[1], 10) # dito
        calc_grid_sizes
        # calculate joint @offsets (3*(n+1) elements, starts with value 0) out of @sizes (n elements) and @grid_*_sizes (n+1 elements)
        @offsets = {0,1}.map {|i| mix(@grid_before_sizes[i], @sizes[i], @grid_after_sizes[i]).accumulate(0)}
        open = true
        wsize = ImVec2.new(@offsets[1][-1], @offsets[0][-1])
        ImGui.set_next_window_content_size(wsize + ImVec2.new(ADDER_CHILD_SIZE,ADDER_CHILD_SIZE)) # seems to need an adder as well

        ImGui.begin_child("###{object_id}", wsize + ImVec2.new(ADDER_GENERAL,ADDER_GENERAL), true, ImGuiWindowFlags::NoDecoration|ImGuiWindowFlags::NoNav|ImGuiWindowFlags::NoScrollWithMouse)
        @sizes_feedback = {Array(Int32).new(@sizes[0].size, 0), Array(Int32).new(@sizes[1].size, 0)} # initialize for learning
        ImGui.push_style_color(ImGuiCol::Border, ImGui.hsv(0, 0, 0, 0)) # to get rid of grey borders
        if @draw_grid_frames
            @grid.grids do |_, grid, bounding_min, bounding_max|
                paint_grid(grid, bounding_min, bounding_max)
            end
        end
        # paint the elements
        @grid.elements do |widget, bounding_min, bounding_max, local_grid, local_index|
            @local_grid, @local_index = local_grid, local_index # make available for whole instance (to avoid passing as args and spoiling standard interface)
            paint_element(widget, bounding_min, bounding_max)
        end
        ImGui.pop_style_color
        ImGui.end_child

        @sizes = @sizes_feedback # take learned sizes for next frame
    end
    def inspect(io : IO) : Nil # used for p'ing (e.g. when debugging)
        io << @grid.inspect
    end
    private def adapt_size(arr : Array(Int32), num : Int32, filler : Int32) # this is actually more of an "Array" method
        delta = arr.size - num
        if delta < 0
            arr.concat(Array(Int32).new(-delta, filler))
        elsif delta > 0
            arr.pop(delta)
        end
    end
    private def paint_element(widget : ElementWidget, bounding_min : RecursiveGrid::Index, bounding_max : RecursiveGrid::Index) : Nil
        # first, prepare child window
        wpos = {0,1}.map {|i| @offsets[i][3*bounding_min[i]+1]}
        wpos = ImVec2.new(wpos[1], wpos[0]) # also transform {row,col} to {x,y}
        wsize = {0,1}.map {|i| @offsets[i][3*bounding_max[i]+2]} # the size for this frame, as learned from prior frame
        wsize = ImVec2.new(wsize[1], wsize[0]) - wpos # also transform {row,col} to {x,y}
        ImGui.set_cursor_pos(wpos)
        ImGui.set_next_window_content_size(wsize + ImVec2.new(ADDER_CONTENT_SIZE,ADDER_CONTENT_SIZE)) # to allow children to query size
        ImGui.begin_child("###{widget.object_id}", wsize, true, ImGuiWindowFlags::NoDecoration|ImGuiWindowFlags::NoNav|ImGuiWindowFlags::NoScrollWithMouse) # noscroll needed, otherwise we have either a too big gap or mouse wheel can scroll
        # second, the real painting
        ImGui.group do
            widget.paint
        end
        # third, retrieve the actually used size
        pmin, pmax = ImGui.get_item_rect_min, ImGui.get_item_rect_max
        ImGui.end_child
        size_feedback = pmax - pmin + ImVec2.new(ADDER_CHILD_SIZE,ADDER_CHILD_SIZE)
        if bounding_min[0] == bounding_max[0] # tbd: currently we only resize according to all non-spanned elements
            @sizes_feedback[0][bounding_min[0]] = {@sizes_feedback[0][bounding_min[0]], size_feedback.y.to_i}.max
        end
        if bounding_min[1] == bounding_max[1] # tbd: currently we only resize according to all non-spanned elements
            @sizes_feedback[1][bounding_min[1]] = {@sizes_feedback[1][bounding_min[1]], size_feedback.x.to_i}.max
        end
    end
    private def paint_grid(grid : RecursiveGrid::Grid(ElementWidget), bounding_min : RecursiveGrid::Index, bounding_max : RecursiveGrid::Index) : Nil
        adder_min, adder_max = @grid2local_offset[grid]
        wpos = {0,1}.map {|i| @offsets[i][3*bounding_min[i]]}
        wpos = ImVec2.new(wpos[1], wpos[0]) + adder_min # also transform {row,col} to {x,y}
        wsize = {0,1}.map {|i| @offsets[i][3*bounding_max[i]+3]}
        wsize = ImVec2.new(wsize[1], wsize[0]) - wpos - adder_max # also transform {row,col} to {x,y}
        adder = ImGui.get_cursor_screen_pos - ImGui.get_cursor_pos
        dl = ImGui.get_window_draw_list
        dl.add_rect(wpos+adder+ImVec2.new(ADDER_GENERAL,ADDER_GENERAL), wpos+wsize+adder, ImGui.get_color_u32(GRID_COLOR))
    end
    private def calc_grid_sizes
        s = @grid.size.map {|el| el+1}
        @grid_before_sizes = {Array(Int32).new(s[0], 0), Array(Int32).new(s[1], 0)}
        @grid_after_sizes = {Array(Int32).new(s[0], 0), Array(Int32).new(s[1], 0)}
        current_before_sizes = {Array(Int32).new(s[0], 0), Array(Int32).new(s[1], 0)}
        current_after_sizes = {Array(Int32).new(s[0], 0), Array(Int32).new(s[1], 0)}
        gridstack = Array(Tuple(RecursiveGrid::Index,RecursiveGrid::Index)).new
        @grid2local_offset.clear
        if @draw_grid_frames
            @grid.grids do |level, grid, bounding_min, bounding_max|
                bounding_max = {bounding_max[0]+1, bounding_max[1]+1}
                delta = gridstack.size - level
                gridstack.pop(delta).each do |bounding_min, bounding_max| # never < 0, so fine
                    add_frame_sizes(@grid_before_sizes, current_before_sizes, bounding_min, -SUBGRID_SPACER)
                    add_frame_sizes(@grid_after_sizes, current_after_sizes, bounding_max, -SUBGRID_SPACER)
                end
                gridstack << {bounding_min, bounding_max}
                @grid2local_offset[grid] = {ImVec2.new(current_before_sizes[1][bounding_min[1]], current_before_sizes[0][bounding_min[0]]),
                    ImVec2.new(current_after_sizes[1][bounding_max[1]], current_after_sizes[0][bounding_max[0]])}
                add_frame_sizes(@grid_before_sizes, current_before_sizes, bounding_min, SUBGRID_SPACER)
                add_frame_sizes(@grid_after_sizes, current_after_sizes, bounding_max, SUBGRID_SPACER)
            end
        end
        (0..1).each {|i| @grid_after_sizes[i].shift} # "after" has a superfluous element at head
    end
    private def add_frame_sizes(grid_sizes : Tuple(Array(Int32),Array(Int32)), current_sizes : Tuple(Array(Int32),Array(Int32)), bounding : RecursiveGrid::Index, delta : Int32)
        (0..1).each do |i|
            current_sizes[i][bounding[i]] += delta
            grid_sizes[i][bounding[i]] = {grid_sizes[i][bounding[i]], current_sizes[i][bounding[i]]}.max
        end
    end
    private def mix(*arrays)
        stride = arrays.size
        s = arrays.map(&.size).max
        res = typeof(arrays[0]).new
        s.times do |i|
            stride.times do |j|
                res << arrays[j][i] if arrays[j].size > i
            end
        end
        res
    end
end

end # module RecursiveGridWidget
