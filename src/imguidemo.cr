require "./recursivegridwidget"

class SimpleWidget < RecursiveGridWidget::ElementWidget
    @@allow_structural_changes = true
    @@count = 0
    def initialize(@gridwidget : RecursiveGridWidget::GridWidget, text : String = @@count.to_s)
        # we store surrounding container (@grid) for maximum flexibility when changing structure (demo specific)
        @@count += 1
        @textbuf = ImGui::TextBuffer.new(text, 50)
    end
    def self.allow_structural_changes=(value : Bool) : Nil
        @@allow_structural_changes = value
    end
    def paint : Nil
        draw_background
        paint_structural_changes_widgets if @@allow_structural_changes
        max_width = ImGui.calc_text_size(@textbuf.to_s).x + 10 # some decoration?
        ImGui.set_next_item_width(max_width)
        ImGui.input_text("##", @textbuf)
    end
    def inspect(io : IO) : Nil # used for p'ing (e.g. when debugging)
        io << "\"#{@textbuf.to_s}\""
    end
    private def paint_structural_changes_widgets
        w = SimpleWidget
        grid = @gridwidget.local_grid
        index = @gridwidget.local_index
        button("T") {grid.replace {|m| m[0...index[0]] + [Array.new(m[0].size) {w.new(@gridwidget)}] + m[index[0]..]} }
        button("B") {grid.replace {|m| m[0..index[0]] + [Array.new(m[0].size) {w.new(@gridwidget)}] + m[index[0]+1..]} }
        button("L") {grid.replace {|m| m.map {|row| row[0...index[1]] + [w.new(@gridwidget)] + row[index[1]..]} } }
        button("R") {grid.replace {|m| m.map {|row| row[0..index[1]] + [w.new(@gridwidget)] + row[index[1]+1..]} } }
        ImGui.dummy(ImVec2.new(10,0)); ImGui.same_line
        button("Sub") {grid.replace {|m| m.map_with_index do |row,ri|
            row.map_with_index do |el,ci|
                {ri,ci}==index ? RecursiveGrid::Grid(RecursiveGridWidget::ElementWidget).new([[el]]) : el
            end
        end}}
        ImGui.new_line
    end
    private def button(text : String, &)
        if ImGui.small_button(text)
            yield
        end
        ImGui.same_line
    end
end

class MyGrid
    @grid : RecursiveGrid::Grid(RecursiveGridWidget::ElementWidget)
    def initialize
        @grid = RecursiveGrid::Grid(RecursiveGridWidget::ElementWidget).new
        @gridwidget = RecursiveGridWidget::GridWidget.new(@grid, true)
        @grid.replace {|m| [[SimpleWidget.new(@gridwidget, "Hello world")]]}
    end
    def paint : Nil
        open = true
        ImGui.set_next_window_size(ImVec2.new(1000, 600), ImGuiCond::FirstUseEver)
        if ImGui.begin("Sample", pointerof(open))
            ImGui.checkbox("allow structural changes", pointerof(@gridwidget.draw_grid_frames))
            SimpleWidget.allow_structural_changes = @gridwidget.draw_grid_frames
            if @gridwidget.draw_grid_frames
                ImGui.text("(BTW: deleting columns and rows can be implemented easily as well)") 
                ImGui.text("structure: #{@grid.inspect}") 
            end
            @gridwidget.paint
            ImGui.end
        end
    end
end

mygrid = MyGrid.new
GUI.gui_loop("RecursiveGrid demo running on Dear ImGui", 1200, 800, 25) do
    mygrid.paint
end
