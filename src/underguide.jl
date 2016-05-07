# Hacks in a new Gadfly GuideElement that behaves like an Annotation but
# sits under (behind) the main plot rather than over it.

immutable Underguide <: Gadfly.GuideElement
    ctx::Context
end

const underguide = Underguide

import Gadfly.render

function render(guide::Underguide, theme::Gadfly.Theme,
                aes::Gadfly.Aesthetics)
    ctx = compose(context(), svgclass("geometry"), guide.ctx)
    return [Gadfly.Guide.PositionedGuide([ctx], 0, Gadfly.Guide.under_guide_position)]
end
