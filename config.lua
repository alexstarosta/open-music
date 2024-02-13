local aspectRatio = display.pixelHeight/display.pixelWidth
local width = 1125
local height = width*aspectRatio

application = {
  content = {
    width = width,
    height = height,
    scale = "letterBox",
    fps = 60
  },
}