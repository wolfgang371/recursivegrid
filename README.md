# recursivegrid

`RecursiveGrid` is a small library, written in Crystal. Main characteristics are:
- two-dimensional grid
- grids can contain grids, recursively
- grid elements can be arbitrary classes
- allow dynamical changes
- an API that fits immediate mode GUI usage

... while abstracting away / hiding...

- grid index counting on the user side
- column and/or row spanning

In addition you can find a sample GUI wrapper (for ImGui) that also abstracts the following aspects:
- pixel counting for both elements and optionally also (sub)grid frames
- automatical resizing of elements

https://github.com/user-attachments/assets/80b9bc63-79d2-4ea2-be8b-4d9116c34e40

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     recursivegrid:
       github: wolfgang371/recursivegrid
   ```

2. Run `shards install`

3. Follow steps in `setup.sh`

4. Run `source ./setup.sh`

## Usage

### Direct library usage

Simple example, taken from specs:

```crystal
require "recursivegrid"

c = RecursiveGrid::Grid(Int32)
grid = c.new([[10, c.new([[20],[30]])]])
grid.size.should eq({2, 2})
grid.get_matrix.should eq([
    [10, 20],
    [10, 30]
])
```

### Sample ImGui based GUI demo

As in `src/imguidemo.cr`, see above video.

## Thanks

Thanks to...
- @ocornut, https://github.com/ocornut/ for Dear ImGui
- @oprypin, https://github.com/oprypin/ for Crystal port of ImGui
- Crystal team, https://github.com/crystal-lang/, https://crystal-lang.org/

## Contributing

1. Fork it (<https://github.com/your-github-user/recursivegrid/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [wolfgang371](https://github.com/wolfgang371) - creator and maintainer
