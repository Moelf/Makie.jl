module CairoMakie

using AbstractPlotting, LinearAlgebra
using Colors, GeometryBasics, FileIO, StaticArrays
import Cairo

using AbstractPlotting: Scene, Lines, Text, Image, Heatmap, Scatter, @key_str, broadcast_foreach
using AbstractPlotting: convert_attribute, @extractvalue, LineSegments, to_ndim, NativeFont
using AbstractPlotting: @info, @get_attribute, Combined
using AbstractPlotting: to_value, to_colormap, extrema_nan
using Cairo: CairoContext, CairoARGBSurface, CairoSVGSurface, CairoPDFSurface

const LIB_CAIRO = if isdefined(Cairo, :libcairo)
    Cairo.libcairo
else
    Cairo._jl_libcairo
end

include("infrastructure.jl")
include("utils.jl")
include("fonts.jl")
include("primitives.jl")

"""
Special method for polys so we don't fall back to atomic meshes, which are much more
complex and slower to draw than standard paths with single color.
"""
function draw_plot(scene::Scene, screen::CairoScreen, poly::Poly)
    # dispatch on input arguments to poly to use smarter drawing methods than
    # meshes if possible
    draw_poly(scene, screen, poly, to_value.(poly.input_args)...)
end

"""
Fallback method for args without special treatment.
"""
function draw_poly(scene::Scene, screen::CairoScreen, poly, args...)
    draw_poly_as_mesh(scene, screen, poly)
end

function draw_poly_as_mesh(scene, screen, poly)
    draw_plot(scene, screen, poly.plots[1])
    draw_plot(scene, screen, poly.plots[2])
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, points::Vector{<:Point2})

    # in the rare case of per-vertex colors redirect to mesh drawing
    if poly.color[] isa Array
        draw_poly_as_mesh(scene, screen, poly)
        return
    end

    model = poly.model[]
    points = project_position.(Ref(scene), points, Ref(model))
    Cairo.move_to(screen.context, points[1]...)
    for p in points[2:end]
        Cairo.line_to(screen.context, p...)
    end
    Cairo.close_path(screen.context)
    Cairo.set_source_rgba(screen.context, rgbatuple(to_color(poly.color[]))...)
    Cairo.fill_preserve(screen.context)
    Cairo.set_source_rgba(screen.context, rgbatuple(to_color(poly.strokecolor[]))...)
    Cairo.set_line_width(screen.context, poly.strokewidth[])
    Cairo.stroke(screen.context)
end

function project_rect(scene, rect::Rect, model)
    mini = project_position(scene, minimum(rect), model)
    maxi = project_position(scene, maximum(rect), model)
    Rect(mini, maxi .- mini)
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, rects::Vector{<:Rect2D})
    model = poly.model[]
    projected_rects = project_rect.(Ref(scene), rects, Ref(model))

    color = poly.color[]
    if color isa AbstractArray{<:Number}
        color = numbers_to_colors(color, poly)
    end
    strokecolor = poly.strokecolor[]
    if strokecolor isa AbstractArray{<:Number}
        strokecolor = numbers_to_colors(strokecolor, poly)
    end

    broadcast_foreach(projected_rects, color, strokecolor, poly.strokewidth[]) do r, c, sc, sw
        Cairo.rectangle(screen.context, origin(r)..., widths(r)...)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(c))...)
        Cairo.fill_preserve(screen.context)
        Cairo.set_source_rgba(screen.context, rgbatuple(to_color(sc))...)
        Cairo.set_line_width(screen.context, sw)
        Cairo.stroke(screen.context)
    end
end

function draw_poly(scene::Scene, screen::CairoScreen, poly, rect::Rect2D)
    draw_poly(scene, screen, poly, [rect])
end

function __init__()
    activate!()
    AbstractPlotting.register_backend!(AbstractPlotting.current_backend[])
end

function display_path(type::String)
    if !(type in ("svg", "png", "pdf", "eps"))
        error("Only \"svg\", \"png\", \"eps\" and \"pdf\" are allowed for `type`. Found: $(type)")
    end
    return joinpath(@__DIR__, "display." * type)
end

function activate!(; inline = true, type = "svg")
    AbstractPlotting.current_backend[] = CairoBackend(display_path(type))
    AbstractPlotting.use_display[] = !inline
    return
end

end
