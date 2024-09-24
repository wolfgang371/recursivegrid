# Grid class that implements the following requirements
# - enable user to create a grid w/o having to deal with indices himself
# - supporting GUI layouting of a flexible, hierarchic grid, without having to "mess" with grid coordinates when defining it
# - template class, i.e. carrying arbitrary element types
# - grid is two-dimensional, index is {row,col} tuple
# - grid is composed of elements (cells)
# - one enumerator for flattened grid elements
# - one enumerator for hierarchical grids (enumerating in DFS order)
# - lazy evaluation, thus supporting later changes as well (still doing some sort of caching, though)
# - automatically deduce spanning rows/columns (always the last corresponding element gets spanned)
# - iterator with constant time access to value and bounding (proper use case for GUI)
# - fit for continuous (re-)calculation, i.e. for immediate mode GUI frameworks
# - not: doing pixel positions and sizes calculation (needs separate layer)
# - GUI independent

module RecursiveGrid

alias Index = Tuple(Int32,Int32) # {row,col}, also used for bounding (min and/or max)

class Grid(T)
    @@version = 0 # caching helper
    @@mutex = Mutex.new
    @version = -1
    @input : Array(Array(T|Grid(T)))
    @offsets = {Array(Int32).new, Array(Int32).new}
    @elements = Array(Tuple(T, Index, Index, Grid(T), Index)).new # {value, bounding_min, bounding_max, local_grid, local_index}
    @grids = Array(Tuple(Int32, Grid(T), Index, Index)).new # {level, grid, bounding_min, bounding_max}
    def initialize(input = Array(Array(T|Grid(T))).new) # default is an empty subgrid
        @input = input.map(&.map(&.as(T|Grid(T)))) # we need to cast to uniform type
    end
    def replace(&) : Nil # for late changes on _input_
        @input = yield(@input).map(&.map(&.as(T|Grid(T)))) # we need to cast to uniform type
        @@mutex.synchronize do
            @@version += 1
        end
    end
    def size : Index # _output_ size
        update
        @offsets.map(&.[-1])
    end
    def grids(&) # block gets {level, grid, bounding_min, bounding_max}, on _output_ side
        update
        @grids.each {|el| yield(el)} # it is safe for the user to do any kind of #replace, as long as it's not interrupted by #size or #get_matrix
    end
    def elements(&) # block gets {value, bounding_min, bounding_max}, on _output_ side
        update
        @elements.each {|el| yield(el)} # it is safe for the user to do any kind of #replace, as long as it's not interrupted by #size or #get_matrix
    end
    def get_matrix : Array(Array(T|Nil)) # flattened _output_; mainly for debugging & testing
        update
        matrix = Array(Array(T|Nil)).new
        size[0].times do
            matrix << [nil.as(T|Nil)] * size[1]
        end
        elements do |value, bounding_min, bounding_max|
            (bounding_min[0]..bounding_max[0]).each do |ri|
                (bounding_min[1]..bounding_max[1]).each do |ci|
                    matrix[ri][ci] = value
                end
            end
        end
        matrix
    end
    def inspect(io : IO) : Nil # used for p'ing (e.g. when debugging)
        io << "Grid(" << @input << ")"
    end
    private def update
        if @version != @@version
            @@mutex.synchronize do
                @version = @@version
            end
            if @input.size > 0
                s = {@input.size, @input[0].size}
            else
                s = {0, 0}
            end
            calc_offsets(s)
            @elements = enumerate_elements# Array(Tuple(T, Index, Index, Grid(T), Index)).new # {value, bounding_min, bounding_max, local_grid, local_index}
            @grids = enumerate_grids # [{0, self, {0,0}, {size[0]-1,size[1]-1} }] # {level, grid, bounding_min, bounding_max}
        end
    end
    private def calc_offsets(s : Index)
        sizes = {Array.new(s[0], 1), Array.new(s[1], 1)} # max. sizes of individual rows and columns
        @input.each.with_index do |row, ri|
            raise("local input matrix needs to be rectangular") if row.size != s[1]
            row.each.with_index do |cell, ci|
                if cell.is_a?(Grid(T))
                    sizes[0][ri] = {sizes[0][ri], cell.size[0]}.max
                    sizes[1][ci] = {sizes[1][ci], cell.size[1]}.max
                end
            end
        end
        @offsets = sizes.map(&.accumulate(0))
    end
    protected def enumerate_elements : Array(Tuple(T, Index, Index, Grid(T), Index)) # {value, bounding_min, bounding_max, local_grid, local_index}
        elements = Array(Tuple(T, Index, Index, Grid(T), Index)).new
        @input.each.with_index do |row, ri|
            row.each.with_index do |cell, ci|
                if cell.is_a?(Grid(T))
                    s = cell.size
                    elements += cell.enumerate_elements.map do |value, bounding_min, bounding_max, local_grid, local_index|
                        bounding_min, bounding_max = span(s, ri, ci, bounding_min, bounding_max)
                        {value, bounding_min, bounding_max, local_grid, local_index}
                    end
                else # cell.is_a?(T)
                    bounding_min, bounding_max = span({1, 1}, ri, ci, {0, 0}, {0, 0})
                    elements << {cell.as(T), bounding_min, bounding_max, self, {ri,ci}}
                end
            end
        end
        elements
    end
    protected def enumerate_grids : Array(Tuple(Int32, Grid(T), Index, Index)) # {level, grid, bounding_min, bounding_max}
        grids = [{0, self, {0,0}, {size[0]-1,size[1]-1} }]
        @input.each.with_index do |row, ri|
            row.each.with_index do |cell, ci|
                if cell.is_a?(Grid(T))
                    s = cell.size
                    grids += cell.enumerate_grids.map do |level, grid, bounding_min, bounding_max|
                        bounding_min, bounding_max = span(s, ri, ci, bounding_min, bounding_max)
                        {level+1, grid, bounding_min, bounding_max}
                    end
                end
            end
        end
        grids
    end
    private def span(s : Index, ri : Int32, ci : Int32, bounding_min : Index, bounding_max : Index) : Tuple(Index, Index)
        bounding_min = {@offsets[0][ri]+bounding_min[0], @offsets[1][ci]+bounding_min[1]}
        bounding_max = {
            bounding_max[0]==s[0]-1 ? @offsets[0][ri+1]-1 : @offsets[0][ri]+bounding_max[0],
            bounding_max[1]==s[1]-1 ? @offsets[1][ci+1]-1 : @offsets[1][ci]+bounding_max[1]
        }
        {bounding_min, bounding_max}
    end
end

end # module RecursiveGrid
