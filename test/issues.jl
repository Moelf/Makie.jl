
@testset "Issues" begin
    @testset "#659 Volume errors if data is not a cube" begin
        fig, ax, vplot = volume(1..8, 1..8, 1..10, rand(8, 8, 10))
        lims = Makie.data_limits(vplot)
        lo, hi = extrema(lims)
        @test all(lo .<= 1)
        @test all(hi .>= (8,8,10))
    end

    @testset "#3979 lossy matrix multiplication" begin
        ps = Point{3, Float64}[[436132.5523666298, 7.002123574681671e6, 505.0239189387989], [436132.5523666298, 7.002123574681671e6, 1279.2437345933633], [436132.5523666298, 7.002884453296079e6, 505.0239189387989], [436132.5523666298, 7.002884453296079e6, 1279.2437345933633], [437151.16775504407, 7.002123574681671e6, 505.0239189387989], [437151.16775504407, 7.002123574681671e6, 1279.2437345933633], [437151.16775504407, 7.002884453296079e6, 505.0239189387989], [437151.16775504407, 7.002884453296079e6, 1279.2437345933633]]
        f, a, p = scatter(ps)
        Makie.update_state_before_display!(f)
        # sanity check: old behavior should fail
        M = Makie.Mat4f(Makie.clip_to_space(a.scene.camera, :data)) *
            Makie.Mat4f(Makie.space_to_clip(a.scene.camera, :data))
        @test !(M ≈ I)
        # this should not
        M = Makie.clip_to_space(a.scene.camera, :data) * Makie.space_to_clip(a.scene.camera, :data)
        @test M ≈ I atol = 1e-4
    end

    @testset "#4416 Merging attributes" begin
        # See https://github.com/MakieOrg/Makie.jl/pull/4416
        theme1 = Theme(Axis = (; titlesize = 10))
        theme2 = Theme(Axis = (; xgridvisible = false))
        merged_theme = merge(theme1, theme2)
        # Test that merging themes does not modify leftmost argument
        @test !haskey(theme1.Axis, :xgridvisible)
        @test !haskey(theme2.Axis, :titlesize)  # sanity check other argument
    end

    @testset "#4722 Transformation passthrough" begin
        scene = Scene(camera = campixel!)
        p = text!(scene, L"\frac{1}{2}")
        translate!(scene, 0, 0, 10)
        @test isassigned(p.transformation.parent)
        @test isassigned(p.plots[1].transformation.parent)
        @test isassigned(p.plots[1].plots[1].transformation.parent)
        @test isassigned(p.plots[1].plots[2].transformation.parent)

        @test scene.transformation.model[][3, 4] == 10.0
        @test p.transformation.model[][3, 4] == 10.0
        @test p.plots[1].transformation.model[][3, 4] == 10.0
        @test p.plots[1].plots[1].transformation.model[][3, 4] == 10.0
        @test p.plots[1].plots[2].transformation.model[][3, 4] == 10.0
    end
end
