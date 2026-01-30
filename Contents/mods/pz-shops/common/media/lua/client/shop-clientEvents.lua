local shopMarkerSystem = require "shop-markers.lua"
Events.OnPostFloorLayerDraw.Add(shopMarkerSystem.render)