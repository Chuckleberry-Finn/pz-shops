local shopMarkerSystem = require "shop-markers.lua"
Events.OnPostRender.Add(shopMarkerSystem.render)
Events.OnPreUIDraw.Add(shopMarkerSystem.renderHoverNames)
