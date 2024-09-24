require "crsfml"
require "imgui"
require "imgui-sfml"

include ImGui::TopLevel

# some convenient ImGui patching
struct ImGui::ImVec2
    def +(other : ImVec2) : ImVec2
        ImVec2.new(x+other.x,y+other.y)
    end
    def -(other : ImVec2) : ImVec2
        ImVec2.new(x-other.x,y-other.y)
    end
    def *(other : Int32) : ImVec2
        ImVec2.new(x*other,y*other)
    end
    def *(other : Float32) : ImVec2
        ImVec2.new(x*other,y*other)
    end
end
struct ImGui::ImVec4
    def +(other : ImVec4) : ImVec4
        ImVec4.new(x+other.x,y+other.y,z+other.z,w+other.w)
    end
    def -(other : ImVec4) : ImVec4
        ImVec4.new(x-other.x,y-other.y,z-other.z,w-other.w)
    end
    def *(other : Int32) : ImVec4
        ImVec4.new(x*other,y*other,z*other,w*other)
    end
    def *(other : Float32) : ImVec4
        ImVec4.new(x*other,y*other,z*other,w*other)
    end
    def hsv2rgb : ImVec4
        r,g,b = ImGui.color_convert_hsv_to_rgb(x, y, z)
        ImVec4.new(r, g, b, w)
    end
    def rgb2hsv : ImVec4
        h,s,v = ImGui.color_convert_rgb_to_hsv(x, y, z)
        ImVec4.new(h, s, v, w)
    end
end

# own general GUI stuff
module GUI
    def self.gui_loop(title, w, h, fps, &proc)
        window = SF::RenderWindow.new(SF::VideoMode.new(w, h), title)
        window.framerate_limit = fps
        ImGui::SFML.init(window)
        ImGui.get_io.ini_filename = nil
        delta_clock = SF::Clock.new
        ImGui.get_io.font_allow_user_scaling = false # doesn't work the way we want
        # needs to be done before #update
        font = ImGui.get_io.fonts.add_font_from_file_ttf("./lib/imgui-sfml/cimgui/imgui/misc/fonts/Cousine-Regular.ttf", 18f32)
        ImGui::SFML.update_font_texture # see https://github.com/ocornut/imgui/issues/1102
        while window.open?
            while (event = window.poll_event)
                ImGui::SFML.process_event(window, event)
                if event.is_a? SF::Event::Closed
                    window.close
                end
            end
            ImGui::SFML.update(window, delta_clock.restart)
            ImGui.push_font(font)
            yield
            ImGui.pop_font
            window.clear
            ImGui::SFML.render(window)
            window.display
        end
        ImGui::SFML.shutdown
    end
end # module GUI
