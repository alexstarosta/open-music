-- stage variables

--display.setStatusBar( display.HiddenStatusBar )
centerX = display.contentCenterX
centerY = display.contentCenterY
screenLeft = display.screenOriginX
screenWidth = display.contentWidth - screenLeft * 2
screenRight = screenLeft + screenWidth
screenTop = display.screenOriginY
screenHeight = display.contentHeight - screenTop * 2
screenBottom = screenTop + screenHeight
display.contentWidth = screenWidth
display.contentHeight = screenHeight

-- variables

local lfs = require "lfs"
local widget = require "widget"

local currentTrack = 1
local currentPlaylist = 2

local currentMainChannel = 1
local currentSecChannel = 2
local currentVolume = 1
local oldCurrentVolume = 1

local muted = false
local fadeMusic = false
local fadetime = 7500
local firstRun = true
local secretActive = false
local wrongDisplay = false

local imagesDir = "playlists/"..currentPlaylist.."/images"
local audioDir = "playlists/"..currentPlaylist.."/audio"
local buttonDir = "assets/buttons"
local playlistCoversDir = "assets/playlistCovers"

local playState = "stopped"
local viewState = "home"
local playlistExpanded = false
local playlistLoading = false

local mainFont = "fonts/mainFont.ttf"
local boldFont = "fonts/boldFont.ttf"

local albumShift = screenWidth*0.45
local albumSize = screenWidth*0.875
local displayShift = albumSize + albumShift + screenWidth*0.1

local imgList, songList, durationList, tracks
local songMs = 0
local songProgress = 0
local songLoops = false
local shuffleMode = false
local shuffleIndex = 1
local shuffleSequence = {}

local menuColor = {25/255, 20/255, 20/255}

local likedSongs = {}
local oldLiked = {}

local albumBlur, albumBlurOffset, album, songName, artistName
local playBtn, pauseBtn, forwardBtn, backBtn, loopBtn, shuffleBtn, progressBarBack, progressBar, progressText, remainingTime, controlPanel, bgBlur, stateText, closeBtn, muteBtn, unmuteBtn, fadeBtn, unfadeBtn, detectSwipeChangeX, detectSwipeChangeY, topMenu, playlistMenu, secretPlaylist, starBtn, miniAlbumBlur, miniBgBlur, miniBarMask, miniSongName, miniAlbum, miniArtistName, miniBarMaskText,miniControlPanel, miniControlPanel, miniPlayBtn, miniPauseBtn, miniProgressBarBack, miniProgressBar, titleContainer, miniBar, musicPlayer, xmenuBtn, playlistbg, createPlaylistViewer, getDurations

local miniBarHeight = screenHeight/16
local textStart = -((screenWidth-albumSize)/1.75 + miniBarHeight*1.3)
local needTitle = false
local titleCount = 1
local titles = {}

local menubg, playlistTopGradient, playlistTopGradient2, playlistGradient, playlistGradient2, playListCoversList, playlistAlbum, playlistAlbumShadow, playlistNames, playlistTitle, playlistDuration, playlistScrollView, playPlaylistBtn, stopPlaylistBtn, menuBtn, volumeSlider, expandPlaylistBtn, playmenubg, profilePlaylistBtn, closePlaylistBtn, originSongList

local playlistViewer = {}
local playlistViewerParent = {}

local homeTitles = {}
local homeTxts = {}
local recs = {}
local homeRecTxt2, homeRec1num, homeRec2num, albumMask, playlistAlbumScrollView
local homeSpacing = 100

local notes = {}
local noterings = {}
local miniGameScore = 0
local miniGameActive = false

-- channel info

local jingleSound = audio.loadSound("assets/Sfx/jingle.mp3")
local waitingSound = audio.loadSound("assets/Sfx/waiting.mp3")

audio.reserveChannels(3)
  -- channel 1 - music 1
  -- channel 2 - music 2
  -- channel 3 - sfx

audio.setVolume( 0.25,{ channel=3 })

-- functions

local function applyBlur(object)
  object.fill.effect = "filter.blurGaussian"
  object.fill.effect.horizontal.blurSize = 400
  object.fill.effect.horizontal.sigma = 140
  object.fill.effect.vertical.blurSize = 40
  object.fill.effect.vertical.sigma = 140
end

local function rgb(hex)
  hex = hex:gsub("#","")
  return {
    tonumber("0x"..hex:sub(1,2))/255,
    tonumber("0x"..hex:sub(3,4))/255,
    tonumber("0x"..hex:sub(5,6))/255
  }
end

local function applyExtraBlur(object)
  object.fill.effect = "filter.blurGaussian"
  object.fill.effect.horizontal.blurSize = 4000
  object.fill.effect.horizontal.sigma = 1400
  object.fill.effect.vertical.blurSize = 400
  object.fill.effect.vertical.sigma = 1400
end

local function applyGradient(object)
  object.fill.effect = "generator.radialGradient"
  object.fill.effect.color1 = {0.25, 0.25, 0.25, 0.6}
  object.fill.effect.color2 = {0, 0, 0, 0.8}
  object.fill.effect.center_and_radiuses  =  {0.5, 0.5, 0.25, 0.75}
  object.fill.effect.aspectRatio  = 1
end

local function formatDuration(ms)
  local minutes = math.floor(ms / 60000)
  local seconds = math.floor((ms % 60000) / 1000)

  local durationString = string.format("%d:%02d", minutes, seconds)
  
  return durationString
end

local function getWelcomeMessage()
  local hour = tonumber(os.date("%H"))
  
  if hour >= 5 and hour < 12 then
    return "Good morning"
  elseif hour >= 12 and hour < 17 then
    return "Good afternoon"
  elseif hour >= 17 and hour < 20 then
    return "Good evening"
  elseif hour >= 20 and hour < 24 then
    return "Good night"
  elseif hour >= 0 and hour < 5 then
    return "Up late, huh"
  else
    return "Welcome Back"
  end
end

local function formatPlaylistTime(playlist)
  if playlist == 0 then
    return "0h 00m"
  end
  local ms = 0
  for i = 1,#playlist do
    ms = ms + playlist[i]
  end
  local minutes = math.floor(ms / 60000)
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60
  return string.format("%dh %0dm", hours, minutes)
end

local function nameToNum(filename)
  local dot_pos = string.find(filename, "%.")
  return tonumber(string.sub(filename, 1, dot_pos - 1))
end

local function nilSongs()
  if songList == nil or #songList == 0 then
    return
  end
  for i = 1,#songList do
    songList[i] = nil
  end
end

local function loadSongs(songs)
  if songs == nil then
    return 0
  end
  local songTable = {}
  for i = 1,#songs do
    songTable[i] = audio.loadStream(songs[i])
  end
  return songTable
end

local function unloadSongs(songs)
  if songs == nil or songs == 0 then
    return
  end
  for i = 1,#songs do
    audio.dispose(songs[i])
    songs[i] = nil
  end
  return {}
end

local function returnDir(path, numName)
  local files = {}
  for file in lfs.dir(path) do
    if file ~= "." and file ~= ".." and file ~= ".DS_Store" then
      local fpath = path .. "/" .. file
      local attr = lfs.attributes(fpath)
      if attr.mode == "file" and numName then
        files[nameToNum(file)] = fpath
      elseif attr.mode == "file" then
        table.insert(files, fpath)
      end
    end
  end
  return files
end

local function readSongs(filename)

  local file = io.open(filename, "r")

  local songs = {}

  local function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(str, pattern, function(c) fields[#fields+1] = c end)
    return fields
  end

  for line in file:lines() do
    local fields = split(line, ",")
    local name = fields[1]
    local artist = fields[2]
    table.insert(songs, {name = name, artist = artist})
  end

  file:close()

  return songs
end

local function randomShufflePath(size)
  
  local sequence = {}
  
  for i = 1, size do
    sequence[#sequence + 1] = i
  end
  
  for i = size - 1, 1, -1 do
    local j = math.random(i + 1)
    sequence[i], sequence[j] = sequence[j], sequence[i]
  end
  
  for i = 1, size do
    if sequence[i] == currentTrack and i ~= 1 then
      sequence[1], sequence[i] = sequence[i], sequence[1]
    end
  end

  return sequence
  
end

local function createNewTitle(place)
  local index = place
  titles[index] = display.newText(tracks[currentTrack].name, (screenWidth-albumSize)/1.75 + miniBarHeight*1.3, centerY - 23, boldFont, 45)
  titles[index].anchorX = 0
  titles[index].pause = 100

  titleContainer:insert(titles[index], true)

  titles[index].x = titles[index].x + screenWidth/3
end

local function moveTitles()
  if viewState ~= "mini" and viewState ~= "home" then
    return
  end

  for i = 1,titleCount do
    
    if titles[i] ~= nil then
      if titles[i+1] ~= nil then
        if titles[i+1].pause < 99 then
          titles[i]:removeSelf()
          titles[i] = nil
        end
      end
    end
    
    if titles[i] ~= nil then 
    
      if titles[i].pause > 0 and titles[i].x - textStart < 2 then
        titles[i].pause = titles[i].pause - 1
      else
        titles[i].x = titles[i].x - 1.5
      end
      if titles[i].pause == 0 and titles[i].x < textStart then
        needTitle = true
        titles[i].pause = titles[i].pause - 1
      end
      
      if math.abs(titles[i].x - textStart) > (string.len(titles[i].text)/2) * 20 and needTitle then
        needTitle = false
        createNewTitle(i+1)
        titleCount = titleCount + 1
      end
      
    else

    end
  end

end

local function updateAssets()
  
  audio.setVolume( currentVolume )
  
  local function deleteAssets()
    albumBlur:removeSelf()
    albumBlurOffset:removeSelf()
    album:removeSelf()
    
    miniAlbumBlur:removeSelf()
    miniAlbum:removeSelf()
    titleContainer:removeSelf()
  end
  
  deleteAssets()

  albumBlur = display.newImage(imgList[currentTrack], centerX, centerY)
  applyBlur(albumBlur)
  albumBlur.width = screenHeight
  albumBlur.height = screenHeight
  musicPlayer:insert(albumBlur)
  
  albumBlurOffset = display.newImage(imgList[currentTrack], centerX, centerY)
  applyBlur(albumBlurOffset)
  albumBlurOffset.fill.effect = "filter.invert"
  albumBlurOffset.width = screenHeight
  albumBlurOffset.height = screenHeight
  albumBlurOffset.alpha = 0.05
  musicPlayer:insert(albumBlurOffset)
  
  albumBlur:toFront()
  bgBlur:toFront()
  albumBlurOffset:toFront()

  album = display.newImage(imgList[currentTrack], centerX, screenWidth*0.45)
  album.anchorY = 0
  musicPlayer:insert(album)

  album.width = albumSize
  album.height = albumSize
  
  songName.text = tracks[currentTrack].name
  artistName.text = tracks[currentTrack].artist
  album:addEventListener("touch", detectSwipeChangeX)
  album:addEventListener("touch", detectSwipeChangeY)
  
  closeBtn:toFront()
  menuBtn:toFront()
  xmenuBtn:toFront()
  stateText:toFront()
  songName:toFront()
  artistName:toFront()
  controlPanel:toFront()
  topMenu:toFront()

  -- mini assets
  
  miniAlbumBlur = display.newImage(imgList[currentTrack], centerX, centerY)
  applyExtraBlur(miniAlbumBlur)
  miniAlbumBlur.width = screenWidth
  miniAlbumBlur.height = screenWidth*2
  miniAlbumBlur:setMask(miniBarMask)
  miniAlbumBlur.maskScaleX = 0.25
  miniAlbumBlur.maskScaleY = 0.2
  miniBar:insert(miniAlbumBlur)

  miniBgBlur:toFront()

  miniSongName = display.newText(tracks[currentTrack].name, (screenWidth-albumSize)/1.75 + miniBarHeight*1.3, centerY - 23, boldFont, 45)
  miniSongName.anchorX = 0
  miniSongName.pause = 100
  miniSongName:toFront()
  miniBar:insert(miniSongName)
  
  titleContainer = display.newContainer(screenWidth/1.8, 100)
  titleContainer.x = centerX
  titleContainer.y = centerY - 23
  titleContainer:insert(miniSongName, true)
  miniBar:insert(titleContainer)

  miniSongName.x = textStart
  
  titles = {}
  table.insert(titles, miniSongName)
  miniSongName:toFront()

  miniAlbum = display.newImage(imgList[currentTrack], (screenWidth-albumSize)/1.75, centerY)
  miniAlbum.anchorX = 0
  miniAlbum.width = miniBarHeight
  miniAlbum.height = miniBarHeight
  miniBar:insert(miniAlbum)

  miniArtistName = display.newText(tracks[currentTrack].artist, textStart*-1 + 8, centerY + 23, mainFont, 35)
  miniArtistName.anchorX = 0
  miniBar:insert(miniArtistName)
  
  miniControlPanel:toFront()
  miniProgressBarBack:toFront()
  miniProgressBar:toFront()
  
end

local function songFinish(event)
  
  if fadeMusic then
    return
  end
  
  if not event.completed then
    return
  end
  
  playState = "stopped"
  audio.rewind(songList[currentTrack])
  audio.stop()
  songMs = 0
  songProgress = 0
  playBtn.alpha = 0
  pauseBtn.alpha = 1
  
  if songLoops then
    audio.play(songList[currentTrack], {channel = currentMainChannel, loops = 0, fadein = 2000, onComplete = songFinish})
    playState = "playing"
  else
    audio.rewind()
    if shuffleMode then
      shuffleIndex = shuffleIndex + 1
      if shuffleIndex > #shuffleSequence then
        shuffleIndex = 1
      end
      currentTrack = shuffleSequence[shuffleIndex]
    else
      currentTrack = currentTrack + 1
      if currentTrack > #songList then
        currentTrack = 1
      end
    end
    updateAssets()
    audio.stop()
    audio.setVolume( currentVolume )
    playBtn.alpha = 0
    pauseBtn.alpha = 1
    miniPlayBtn.alpha = 0
    miniPauseBtn.alpha = 1
    playPlaylistBtn.alpha = 0
    stopPlaylistBtn.alpha = 1
    
    songMs = 0
    songProgress = 0
    audio.play(songList[currentTrack], {channel = currentMainChannel, loops = 0, fadein = 2000, onComplete = songFinish})
    playState = "playing" 
  end
  
end

local function changeSong()
  updateAssets()
  audio.stop()
  audio.setVolume(currentVolume)
  audio.setVolume( 1, { channel=currentMainChannel } )
  audio.setVolume( 1, { channel=currentSecChannel } )
  playBtn.alpha = 0
  pauseBtn.alpha = 1
  miniPlayBtn.alpha = 0
  miniPauseBtn.alpha = 1
  playPlaylistBtn.alpha = 0
  stopPlaylistBtn.alpha = 1
  songMs = 0
  songProgress = 0
  audio.play(songList[currentTrack], {channel = currentMainChannel, loops = 0, fadein = 1000, onComplete = songFinish})
  playState = "playing" 
end

local function fadeNextSong()
  playState = "fading"
  songMs = 0
  songProgress = 0
  playBtn.alpha = 0
  pauseBtn.alpha = 1
  audio.fadeOut( { channel=currentMainChannel, time=fadetime } )
  
  if not songLoops then
    if shuffleMode then
      shuffleIndex = shuffleIndex + 1
      if shuffleIndex > #shuffleSequence then
        shuffleIndex = 1
      end
      currentTrack = shuffleSequence[shuffleIndex]
    else
      currentTrack = currentTrack + 1
      if currentTrack > #songList then
        currentTrack = 1
      end
    end
  end
    
  audio.setVolume( currentVolume )
  playBtn.alpha = 0
  pauseBtn.alpha = 1
  miniPlayBtn.alpha = 0
  miniPauseBtn.alpha = 1
  playPlaylistBtn.alpha = 0
  stopPlaylistBtn.alpha = 1
  audio.play(songList[currentTrack], {channel = currentSecChannel, loops = 0, fadein = fadetime, onComplete = songFinish})
  currentMainChannel, currentSecChannel = currentSecChannel, currentMainChannel
  
  timer.performWithDelay( fadetime, function()
    audio.rewind({ channel=currentSecChannel })
    audio.stop(currentSecChannel)
    audio.setVolume(1,{ channel=currentSecChannel })
    audio.setVolume( 1, { channel=currentMainChannel } )
    updateAssets()
    playState = "playing" 
  end)
    
end

local function getLikedSongs()
  if #likedSongs == 0 then
    return nil
  end
  local likedSongRefrences = {}
  for i = 1,#likedSongs do
    likedSongRefrences[i] = "playlists/"..likedSongs[i].id[1].."/audio/"..likedSongs[i].id[2]..".mp3"
  end
  return likedSongRefrences
end

local function getLikedTracks()
  if #likedSongs == 0 then
    return nil
  end
  local likedSongTracks = {}
  for i = 1,#likedSongs do
    likedSongTracks[i] = readSongs("playlists/"..likedSongs[i].id[1].."/discography.txt")[likedSongs[i].id[2]]
  end
  return likedSongTracks
end

local function fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local function getLikedImages()
  if #likedSongs == 0 then
    return nil
  end
  local likedSongImages = {}
  for i = 1,#likedSongs do
    likedSongImages[i] = "playlists/"..likedSongs[i].id[1].."/images/"..likedSongs[i].id[2]..".jpg"
    if not fileExists(likedSongImages[i]) then
      likedSongImages[i] = "playlists/"..likedSongs[i].id[1].."/images/"..likedSongs[i].id[2]..".jpeg"
      if not fileExists(likedSongImages[i]) then
        likedSongImages[i] = "playlists/"..likedSongs[i].id[1].."/images/"..likedSongs[i].id[2]..".png"
      end
    end
  end

  return likedSongImages
end

local function updatePlaylist()
  shuffleBtn.alpha = 0.3
  shuffleMode = false
  
  songList = unloadSongs(songList)
  
  if currentPlaylist < 4 then
    audioDir = "playlists/"..currentPlaylist.."/audio"
    tracks = readSongs("playlists/"..currentPlaylist.."/discography.txt")
    imgList = returnDir("playlists/"..currentPlaylist.."/images", true)
    
    songList = {}
    songList = returnDir(audioDir, true)
    songList = loadSongs(songList)
    durationList = getDurations(songList)
  else
    tracks = getLikedTracks()
    imgList = getLikedImages()
    songList = getLikedSongs()
    songList = loadSongs(songList)
    durationList = getDurations(songList)
  end
  
end

local function expandViewer(inout, num)
  local atime = 500
  if num then
    atime = num
  end
  local atransition = easing.outCubic
  if inout then
    transition.to(playlistAlbum, {time = atime, y = playlistAlbum.y + screenHeight/4, alpha = 1,transition = atransition})
    transition.to(playlistAlbumShadow, {time = atime, y = playlistAlbumShadow.y + screenHeight/4, alpha = 1,transition = atransition})
    transition.to(playlistTitle, {time = atime, y = albumSize*1.075, x = (screenWidth-albumSize)/2, anchorX = 0, transition = atransition})
    transition.to(playlistDuration, {time = atime, y = playlistDuration.y + screenHeight/3, x = (screenWidth-albumSize)/2, anchorX = 0, transition = atransition})
    transition.to(playPlaylistBtn, {time = atime, width = playPlaylistBtn.width*2, height = playPlaylistBtn.height*2, y = albumSize*1.1, x =  screenWidth - (screenWidth-albumSize)/2, anchorX = 1, transition = atransition})
    transition.to(stopPlaylistBtn, {time = atime, width = stopPlaylistBtn.width*2, height = stopPlaylistBtn.height*2, y = albumSize*1.1, x =  screenWidth - (screenWidth-albumSize)/2, anchorX = 1, transition = atransition})
    
    transition.to(playlistTopGradient, {time = atime, y = playlistTopGradient.y + screenHeight/4*1.15, transition = atransition})
    transition.to(playlistTopGradient2, {time = atime, y = playlistTopGradient2.y + screenHeight/4*1.15,  transition = atransition})
    playlistScrollView:setScrollHeight(playlistScrollView:getView()._scrollHeight + screenHeight/4)
    transition.to(playlistScrollView, {time = atime, y = playlistScrollView.y + screenHeight/4, height = playlistScrollView.height - screenHeight/2, transition = atransition, onComplete = function() playlistExpanded = false end})
  else
    transition.to(playlistAlbum, {time = atime, y = playlistAlbum.y - screenHeight/4, alpha = 0,transition = atransition})
    transition.to(playlistAlbumShadow, {time = atime, y = playlistAlbumShadow.y - screenHeight/4, alpha = 0,transition = atransition})
    transition.to(playlistTitle, {time = atime, y = playlistTitle.y - screenHeight/3, x = centerX,anchorX = 0.5, transition = atransition})
    transition.to(playlistDuration, {time = atime, y = playlistDuration.y - screenHeight/3, x = centerX, anchorX = 0.5, transition = atransition})
    transition.to(playPlaylistBtn, {time = atime, width = playPlaylistBtn.width/2, height = playPlaylistBtn.height/2, y = playlistDuration.y - screenHeight/3 + playPlaylistBtn.height*0.75, x = centerX, anchorX = 0.5, transition = atransition})
    transition.to(stopPlaylistBtn, {time = atime, width = stopPlaylistBtn.width/2, height = stopPlaylistBtn.height/2, y = playlistDuration.y - screenHeight/3 + stopPlaylistBtn.height*0.75, x = centerX, anchorX = 0.5, transition = atransition})
    
    transition.to(playlistTopGradient, {time = atime, y = playlistTopGradient.y - screenHeight/4*1.15, transition = atransition})
    transition.to(playlistTopGradient2, {time = atime, y = playlistTopGradient2.y - screenHeight/4*1.15,  transition = atransition})
    playlistScrollView:setScrollHeight(playlistScrollView:getView()._scrollHeight - screenHeight/4)
    transition.to(playlistScrollView, {time = atime, y = playlistScrollView.y - screenHeight/4, height = playlistScrollView.height + screenHeight/2, transition = atransition, onComplete = function() playlistExpanded = true end})
  end
end

local function playlistVisualUpdate()
  
  createPlaylistViewer()
  
  local accentColor = rgb(playlistNames[currentPlaylist].artist)
  playlistGradient = {
      type = "gradient",
      color1 = { accentColor[1], accentColor[2], accentColor[3], 1 },
      color2 = { menuColor[1], menuColor[2], menuColor[3], 1 },
      direction = "bottom"
  }
  playlistTopGradient.fill = playlistGradient
  
  playlistAlbum:removeSelf()
  playlistAlbum = display.newImage(playListCoversList[currentPlaylist], centerX, screenWidth*0.45/2)
  playlistAlbum.anchorY = 0
  playlistAlbum.width = albumSize/1.5
  playlistAlbum.height = albumSize/1.5
  playlistMenu:insert(playlistAlbum)
  playlistLoading = true
  
  playlistTitle.text = playlistNames[currentPlaylist].name
  
  if currentPlaylist < 4 then
    local songs = loadSongs(returnDir("playlists/"..currentPlaylist.."/audio", true))
    playlistDuration.text = formatPlaylistTime(getDurations(songs))
    songs = unloadSongs(songs)
  else
    local songs = loadSongs(getLikedSongs(likedSongs))
    playlistDuration.text = formatPlaylistTime(getDurations(songs))
    songs = unloadSongs(songs)
  end
end

local function checkSecret(time)
  if time == "open" then
    if secretActive then
      oldLiked = likedSongs
      secretPlaylist()
    end
  elseif time == "close" then
    if secretActive then
      for i,v in pairs(recs[4]) do
        v.alpha = 0
      end
      likedSongs = oldLiked
    end
    secretActive = false
  end
end

local function btnCheck()
  if miniGameActive or wrongDisplay then
    return true
  end
  return false
end

local function btnScreenCheck(btn) 
  if btn.name == "stopPlaylistBtn" or btn.name == "playPlaylistBtn" or btn.name == "expandPlaylist" then
    if viewState ~= "mini" then
      return true
    end
  end
  return false
end

local function changeStar()
  if audio.isChannelActive(currentMainChannel) then
    starBtn.alpha = 0
  else
    starBtn.alpha = 0.3
  end
end

local function closePlayer()
  transition.to(musicPlayer, {y = screenHeight*1.5, time = 600, transition = easing.inCubic, onComplete =   function()  
  miniBar:toFront()
  transition.to(miniBar, {y = screenHeight - miniBarHeight*1.5, time = 600, transition = easing.outBack}) 
    if playlistbg.x == centerX then
      viewState = "mini"
    else
      viewState = "home"
    end
  end})
end

local function resetPlayButtons()
  playBtn.alpha = 0
  pauseBtn.alpha = 1
  miniPlayBtn.alpha = 0
  miniPauseBtn.alpha = 1
  playPlaylistBtn.alpha = 0
  stopPlaylistBtn.alpha = 1
end

local function playPause()
  if playState == "stopped" then
    audio.play(songList[currentTrack], {channel = 1, loops = 0, fadein = 200, onComplete = songFinish})
    resetPlayButtons()
    playState = "playing" 
  elseif playState == "paused" then
    audio.resume(currentMainChannel)
    audio.resume(currentSecChannel)
    resetPlayButtons()
    playState = "playing" 
  elseif playState == "playing" or playState == "fading" then
    audio.pause(currentMainChannel)
    audio.pause(currentSecChannel)
    updateAssets()
    playBtn.alpha = 1
    pauseBtn.alpha = 0
    miniPlayBtn.alpha = 1
    miniPauseBtn.alpha = 0
    playPlaylistBtn.alpha = 1
    stopPlaylistBtn.alpha = 0
    playState = "paused"
  end
end

local function playStopPlaylist()
  if currentPlaylist == 4 and #likedSongs == 0 then
    return
  end
  
  if playlistLoading then
    currentTrack = 1
    audio.rewind()
    audio.stop()
    updatePlaylist()
    audio.setVolume(currentVolume)
    audio.setVolume( 1, { channel=currentMainChannel } )
    audio.setVolume( 1, { channel=currentSecChannel } )
    songMs = 0
    songProgress = 0
    playlistLoading = false
  end
  
  if playState == "stopped" or playState == "paused" then
    audio.rewind()
    audio.stop()
    audio.setVolume( currentVolume )
    currentTrack = 1
    audio.play(songList[currentTrack], {channel = currentMainChannel, loops = 0, fadein = 200, onComplete = songFinish})
    miniBar:toFront()
    transition.to(miniBar, {y = screenHeight - miniBarHeight*1.5, time = 600, transition = easing.outBack})
    updateAssets()
    resetPlayButtons()
    playState = "playing" 
  elseif playState == "playing" or playState == "fading" then
    audio.rewind()
    audio.stop()
    transition.to(miniBar, {y = screenHeight + miniBarHeight*1.5, time = 600, transition = easing.outBack})
    songProgress = 0
    playBtn.alpha = 1
    pauseBtn.alpha = 0
    miniPlayBtn.alpha = 1
    miniPauseBtn.alpha = 0
    playPlaylistBtn.alpha = 1
    stopPlaylistBtn.alpha = 0
    playState = "stopped"
  end
end

local function btnTap(event)
  
  local button = event.target
  
  if btnCheck() or btnScreenCheck(event.target) then
    return
  end
  
  if button.operation == "playPause" then
    playPause()
  end
  
  if button.operation == "closePlaylist" then
    
    if viewState ~= "mini" then
      return
    end
    
    checkSecret("close")
    
    local songs = loadSongs(getLikedSongs(likedSongs))
    recs[3].duration.text = formatPlaylistTime(getDurations(songs))
    songs = unloadSongs(songs)
    
    playlistMenu.anchorChildren = false
    playlistMenu.x = 0
    playlistMenu.y = 0
    transition.to(playlistbg, {x = -screenWidth, time = 600, transition = easing.inCubic})
    transition.to(playlistScrollView, {x = playlistScrollView.x-screenWidth, time = 600, transition = easing.inCubic})
    transition.to(playlistMenu, {x = playlistMenu.x-screenWidth, time = 600, transition = easing.inCubic, onComplete = function()
      playlistMenu.anchorChildren = true
      playlistMenu.x = centerX-screenWidth*1.5
      playlistMenu.y = centerY
      viewState = "home"
    end})
  end
  
  if button.operation == "openPlaylist" then
    if viewState ~= "home" then
      return
    end
    
    checkSecret("open")
    viewState = "mini"
    
    if playlistExpanded then
      expandViewer(playlistExpanded, 10)
      expandPlaylistBtn.alpha = 0.3
    end
    
    currentPlaylist = button.playlist
    
    playlistVisualUpdate()
  end
  
  if button.operation == "expandPlaylist" then
    if playlistExpanded and playlistExpanded ~= 0 then
      playlistExpanded = 0
      expandPlaylistBtn.alpha = 0.3
      expandViewer(true, nil)
    elseif playlistExpanded ~= 0 then
      playlistExpanded = 0
      expandPlaylistBtn.alpha = 1
      expandViewer(false, nil)
    end
  end
  
  if button.operation == "menu" then
    local atime = 400
    if menuBtn.alpha == 0 then
      menuBtn.alpha = 1
      xmenuBtn.alpha = 0
      transition.to(topMenu, {time = atime, alpha = 0})
    elseif menuBtn.alpha == 1 then
      menuBtn.alpha = 0
      xmenuBtn.alpha = 1
      transition.to(topMenu, {time = atime, alpha = 1})
    end
  end
  
  if button.operation == "playStopPlaylist" then
    playStopPlaylist()
  end
  
  if button.operation == "forward" then
    audio.rewind()
    if shuffleMode then
      shuffleIndex = shuffleIndex + 1
      if shuffleIndex > #shuffleSequence then
        shuffleIndex = 1
      end
      currentTrack = shuffleSequence[shuffleIndex]
    else
      currentTrack = currentTrack + 1
      if currentTrack > #songList then
        currentTrack = 1
      end
    end
    changeSong()
  end
  
  if button.operation == "backward" then
    audio.rewind()
    if shuffleMode then
      shuffleIndex = shuffleIndex - 1
      if shuffleIndex < 1 then
        shuffleIndex = #shuffleSequence
      end
      currentTrack = shuffleSequence[shuffleIndex]
    else
      currentTrack = currentTrack - 1
      if currentTrack < 1 then
        currentTrack = #songList
      end
    end
    changeSong()
  end
  
  if button.operation == "loop" then
    if songLoops then
      loopBtn.alpha = 0.3
      songLoops = false
    else
      loopBtn.alpha = 1
      songLoops = true
      if fadeMusic then
        fadeBtn.alpha = 1
        unfadeBtn.alpha = 0
        fadeMusic = false
      end
    end
  end
  
  if button.operation == "shuffle" then
    if shuffleMode then
      shuffleBtn.alpha = 0.3
      shuffleMode = false
    else
      shuffleBtn.alpha = 1
      shuffleMode = true
      shuffleIndex = 1
      shuffleSequence = randomShufflePath(#tracks)
    end
  end
  
  if button.operation == "closePlayer" then
    closePlayer()
  end
  
  if button.operation == "muteUnmute" then
    if not audio.isChannelActive(currentMainChannel) then
      return
    end
    if muted then
      currentVolume = oldCurrentVolume
      audio.setVolume(currentVolume)
      muteBtn.alpha = 1
      unmuteBtn.alpha = 0
      volumeSlider:setValue(100 * currentVolume)
      muted = false
    else
      oldCurrentVolume = currentVolume
      currentVolume = 0
      audio.setVolume(0)
      muteBtn.alpha = 0
      unmuteBtn.alpha = 1
      volumeSlider:setValue(0)
      muted = true
    end
  end
  
  if button.operation == "fadeUnfade" then
    if (songMs/durationList[currentTrack])*100 > 90 then
      return
    end
    
    if fadeMusic then
      fadeBtn.alpha = 1
      unfadeBtn.alpha = 0
      fadeMusic = false
    else
      if not songLoops and #songList > 2 then
        fadeBtn.alpha = 0
        unfadeBtn.alpha = 1
        fadeMusic = true
      end
    end
  end
   
  changeStar()
   
end

function secretPlaylist()
  likedSongs = {{id={1,10}},{id={1,7}},{id={1,13}},{id={1,16}},{id={1,19}},{id={1,25}},{id={1,26}},{id={2,1}},{id={2,2}},{id={2,5}},{id={2,7}},{id={2,30}},{id={3,1}},{id={3,8}},{id={3,19}}}
end

function detectSwipeChangeX(event)
  if ( event.phase == "ended" ) then
    local swipeLength = math.abs(event.x - event.xStart)
    local threshold = screenWidth/6
    if ( swipeLength > threshold ) then
      if ( (event.x - event.xStart) < 0 ) then
       audio.rewind()
        if shuffleMode then
          shuffleIndex = shuffleIndex + 1
          if shuffleIndex > #shuffleSequence then
            shuffleIndex = 1
          end
          currentTrack = shuffleSequence[shuffleIndex]
        else
          currentTrack = currentTrack + 1
          if currentTrack > #songList then
            currentTrack = 1
          end
        end
        changeSong()
      else
        audio.rewind()
        if shuffleMode then
          shuffleIndex = shuffleIndex - 1
          if shuffleIndex < 1 then
            shuffleIndex = #shuffleSequence
          end
          currentTrack = shuffleSequence[shuffleIndex]
        else
          currentTrack = currentTrack - 1
          if currentTrack < 1 then
            currentTrack = #songList
          end
        end
        changeSong()
      end
    end
  end
  return true
end

function detectSwipeChangeY(event)
  if ( event.phase == "ended" or event.phase == "moved" ) then
    local swipeLength = math.abs(event.y - event.yStart)
    local threshold 
    if viewState == "mini" or viewState == "home" then
      threshold = screenWidth/10
    else
      threshold = screenWidth/2
    end
    if ( swipeLength > threshold ) then
      if ( (event.y - event.yStart) < 0 and viewState == "mini" or viewState == "home" ) then
        transition.to(miniBar, {y = screenHeight + miniBarHeight*1.5, time = 600, transition = easing.inBack, onComplete = function()  
          musicPlayer:toFront()
          transition.to(musicPlayer, {y =centerY, time = 600, transition = easing.outCubic}) 
        end})
        viewState = "player"
      elseif ( (event.y - event.yStart) > 0 and viewState == "player" ) then
        transition.to(musicPlayer, {y = screenHeight*1.5, time = 600, transition = easing.inCubic, onComplete = function()  
          miniBar:toFront()
          transition.to(miniBar, {y = screenHeight - miniBarHeight*1.5, time = 600, transition = easing.outBack}) 
        end})
        viewState = "mini"
      end
    end
  end
  return true
end

local function lightButtons(btnGroup)
  for i = 1,btnGroup.numChildren do
    btnGroup[i].fill.effect = "filter.invert"
  end
end

local function addEvents(btnGroup)
  for i = 1,btnGroup.numChildren do
    btnGroup[i]:addEventListener("tap", btnTap)
  end
end

function getDurations(songs)
  if songs == 0 then
    return 0
  end
  local songTable = {}
  for i = 1,#songs do
    songTable[i] = audio.getDuration(songs[i])
  end
  return songTable
end

local function updateProgress()

  local function updateText()
    local oldText = progressText.text
    
    if songMs >= durationList[currentTrack] then
      songMs = durationList[currentTrack]
    end
    
    progressText.text = formatDuration(songMs)
    if oldText ~= progressText.text then
      remainingTime.text = "-"..formatDuration(durationList[currentTrack]-songMs)
    end
  end
  
  if audio.isChannelPlaying(currentMainChannel) then
    songMs = (songMs + 1000/display.fps)
    songProgress = (songMs/durationList[currentTrack])*100
    
    if songProgress >= 100 then
      songProgress = 100
    end
    
    if durationList[currentTrack]-songMs < fadetime + 50 and fadeMusic then
      fadeNextSong()
    end
    
    progressBar.width = (songProgress/100)*progressBarBack.width
    miniProgressBar.width = (songProgress/100)*miniProgressBarBack.width
    updateText()
  end
end

local function inLiked(idsong)
  for i = 1,#likedSongs do
    if likedSongs[i].id[1] == idsong[1] and likedSongs[i].id[2] == idsong[2] then
      return true
    end
  end
  return false
end

local function removeLiked(idsong)
  local removeIndex = 1
  unloadSongs({"playlists/"..idsong[1].."/audio/"..idsong[2]..".mp3"})
  for i = 1,#likedSongs do
    if likedSongs[i].id[1] == idsong[1] and likedSongs[i].id[2] == idsong[2] then
      removeIndex = i
    end
  end
  for i = removeIndex,#likedSongs do
    likedSongs[i] = likedSongs[i+1]
  end
end

local function addNewLiked(event)
  if event.target.alpha == 1 then
    event.target.alpha = 0.3
    removeLiked(event.target.id)
  else
    likedSongs[#likedSongs + 1] = {
      id = event.target.id,
    }
    event.target.alpha = 1
  end
end

local function createScrollView(playlistGrp)
  playlistScrollView = widget.newScrollView(
    {
      x = -screenWidth,
      y = centerY,
      width = screenWidth,
      height = screenHeight,
      horizontalScrollDisabled = true,
      hideBackground = true,
      hideScrollBar = true,
      scrollHeight = (miniBarHeight*1.1*(#tracks)),
      bottomPadding = miniBarHeight*2.5
    }
  )
  if playlistGrp then
    for i = 1,#playlistGrp do
      playlistScrollView:insert(playlistGrp[i])
    end
  end
  if firstRun then
    firstRun = false
  else
    transition.to(playlistScrollView, {x = centerX, anchorX = 0.5, time = 800, transition = easing.outCubic})
    transition.to(playlistbg, {x = centerX, anchorX = 0.5, time = 800, transition = easing.outCubic})
    transition.to(playlistMenu, {x = centerX, anchorX = 0.5, time = 800, transition = easing.outCubic})
  end
  playlistbg:toFront()
  playlistScrollView:toFront()
  playlistMenu:toFront()
  miniBar:toFront()
end

function createPlaylistViewer()
  
  local tracks
  local imgList
  
  if currentPlaylist >= 4 then
    tracks = getLikedTracks()
    imgList = getLikedImages()
  else
    tracks = readSongs("playlists/"..currentPlaylist.."/discography.txt")
    imgList = returnDir("playlists/"..currentPlaylist.."/images", true)
  end
  
  if playlistViewer[1] ~= nil then
    for i = 1,#playlistViewer do
      playlistViewer[i].group:removeSelf()
    end
    for i = 1,#playlistViewerParent do
      playlistViewerParent[i] = nil
    end
    playlistScrollView:removeSelf()
  end
  
  local playlistEndText
  
  if tracks ~= nil then
    for i = 1,#tracks do
      playlistViewer[i] = {}
      playlistViewer[i].group = display.newGroup()
      playlistViewer[i].group.anchorChildren = true
      playlistViewer[i].group.x = centerX
      playlistViewer[i].group.y = centerY + (miniBarHeight*1.1*(i))
      
      playlistViewer[i].songName = display.newText(playlistViewer[i].group, tracks[i].name, textStart*-1 - 20, centerY - 23, boldFont, 40)
      playlistViewer[i].songName.anchorX = 0
      
      local grad = {
        type = "gradient",
        color1 = { 25/255, 20/255, 20/255, 1  },
        color2 = { 25/255, 20/255, 20/255, 0 },
        direction = "left"
      }
      
      if string.len(tracks[i].name) > 30 then
        playlistViewer[i].gradientRect1 = display.newRect(playlistViewer[i].group, screenWidth - (screenWidth-albumSize)/1.75, centerY, miniBarHeight*0.5, miniBarHeight)
        playlistViewer[i].gradientRect1.anchorX = 1
        playlistViewer[i].gradientRect1.fill = {25/255, 20/255, 20/255}
        
        playlistViewer[i].gradientRect2 = display.newRect(playlistViewer[i].group, screenWidth - (screenWidth-albumSize)/1.75 - miniBarHeight*0.5, centerY, miniBarHeight, miniBarHeight)
        playlistViewer[i].gradientRect2.anchorX = 1
        playlistViewer[i].gradientRect2.fill = grad
      end
      
      playlistViewer[i].album = display.newImage(playlistViewer[i].group, imgList[i], (screenWidth-albumSize)/1.75, centerY)
      playlistViewer[i].album.anchorX = 0
      playlistViewer[i].album.width = miniBarHeight*0.9
      playlistViewer[i].album.height = miniBarHeight*0.9

      playlistViewer[i].artistName = display.newText(playlistViewer[i].group, tracks[i].artist, textStart*-1 - 20, centerY + 23, mainFont, 35)
      playlistViewer[i].artistName.anchorX = 0
      
      playlistViewer[i].likeBtn = display.newImageRect(playlistViewer[i].group, buttonDir.."/like.png", 55, 55)
      playlistViewer[i].likeBtn.x = screenWidth - (screenWidth-albumSize)/1.75
      playlistViewer[i].likeBtn.anchorX = 1
      playlistViewer[i].likeBtn.y = centerY
      if inLiked({currentPlaylist, i}) then
        playlistViewer[i].likeBtn.alpha = 1
      else
        playlistViewer[i].likeBtn.alpha = 0.3
      end
      playlistViewer[i].likeBtn.fill.effect = "filter.invert"
      playlistViewer[i].likeBtn.trackNum = i
      playlistViewer[i].likeBtn:addEventListener("tap", addNewLiked)
      playlistViewer[i].likeBtn.id = {currentPlaylist, i}
      if currentPlaylist >= 4 then
        playlistViewer[i].likeBtn.alpha = 0
      end
        
      
      playlistViewerParent[i] = playlistViewer[i].group
    end
  
    playlistEndText = display.newText("end of playlist :)", centerX, centerY + (miniBarHeight*1.1*(#tracks+1)), boldFont, 40)
    playlistEndText.alpha = 0.2
    playlistViewerParent[#playlistViewerParent + 1] = playlistEndText
  else
    playlistEndText = display.newText("no songs :(", centerX, centerY + (miniBarHeight*1.1*(1)), boldFont, 40)
    playlistEndText.alpha = 0.2
    playlistViewerParent[#playlistViewerParent + 1] = playlistEndText
  end
  
  createScrollView(playlistViewerParent)
  
end

local function createHomeRec(x, y, playlist)
  
  local homeRec = {}
  homeRec.box = display.newRoundedRect(x, y, (screenWidth - (screenWidth-albumSize)/2*2.5)/2, miniBarHeight, 25)
  homeRec.box.alpha = 0.25
  homeRec.box.operation = "openPlaylist"
  homeRec.box.playlist = playlist
  homeRec.box:addEventListener("tap", btnTap)
  homeRec.box.name = "box"
  
  if playlist == 5 then
    homeRec.box.fill = rgb(playlistNames[playlist].artist)
    homeRec.box.alpha = 0.3
  end
  
  homeRec.album = display.newImage(playListCoversList[playlist], x - screenWidth/5.1, y)
  homeRec.album.anchorX = 0
  homeRec.album.width = miniBarHeight*0.75
  homeRec.album.height = miniBarHeight*0.75
  
  homeRec.title = display.newText(playlistNames[playlist].name,  x - screenWidth/5.1 + miniBarHeight*0.9, y - 20, boldFont, 25)
  homeRec.title.anchorX = 0
  
  if playlist ~= 5 then
    local durations
    if playlist ~= 4 then
      local songs = loadSongs(returnDir("playlists/"..playlist.."/audio", true))
      durations = formatPlaylistTime(getDurations(songs))
      songs = unloadSongs(songs)
    else
      local songs = loadSongs(getLikedSongs(likedSongs))
      durations = formatPlaylistTime(getDurations(songs))
      songs = unloadSongs(songs)
    end
  
  homeRec.duration = display.newText(durations,  x - screenWidth/5.1 + miniBarHeight*0.9, y + 20, mainFont, 25)
  homeRec.duration.anchorX = 0
  end
  
  return homeRec
end

local function createPlaylistScroll()
  local playlistTab = {}
  for i = 1,#playlistNames - 1 do
    playlistTab[i] = {}
    
    local x = 0
    local y = 0
    
    playlistTab[i].group = display.newGroup()
    playlistTab[i].group.anchorChildren = true
    playlistTab[i].group.x = ((albumSize/1.5+100)*(i-0.5)) + (screenWidth-albumSize)/4
    playlistTab[i].group.y = centerY - 75
    playlistTab[i].group.operation = "openPlaylist"
    playlistTab[i].group.playlist = i
    playlistTab[i].group:addEventListener("tap", btnTap)
    
    playlistTab[i].box = display.newRoundedRect(playlistTab[i].group,x,y, albumSize/1.5+30, albumSize/1.5+30, 50)
    playlistTab[i].box.fill = rgb(playlistNames[i].artist)
    playlistTab[i].box.alpha = 0.3

    playlistTab[i].playlistAlbum = display.newImage(playlistTab[i].group,playListCoversList[i], x, y)
    playlistTab[i].playlistAlbum.width = albumSize/1.5
    playlistTab[i].playlistAlbum.height = albumSize/1.5
    playlistTab[i].playlistAlbum:setMask(albumMask)
    playlistTab[i].playlistAlbum.maskScaleX = 1.8
    playlistTab[i].playlistAlbum.maskScaleY = 1.8
  end
  
  playlistAlbumScrollView = widget.newScrollView(
    {
      x =  centerX,
      y = centerY,
      width = screenWidth,
      height = screenHeight,
      verticalScrollDisabled = true,
      hideBackground = true,
      hideScrollBar = true,
      scrollHeight = screenHeight/2,
      scrollWidth = (albumSize/1.5*(#playlistTab)),
      rightPadding = (screenWidth-albumSize)/2
    }
  )
  for i = 1,#playlistTab do
    playlistAlbumScrollView:insert(playlistTab[i].group)
  end
end

local function createShine()
  local shine = display.newImage("assets/shine.png", 50,50)
  shine:scale(0.11,0.11)
  shine.x = recs[4].album.x + recs[4].album.width/2
  shine.y = recs[4].album.y
  shine.fill.effect = "filter.invert"
  shine.alpha = 0
  recs[4].album:toFront()
  transition.to(shine, {time = 3000, rotation = 360, delay = 1000, alpha = 0.5, onComplete = function()
    transition.to(shine, {time = 2000, rotation = 360 + 180, alpha = 0})
  end})
end

local function showSecret()
  secretActive = true
  for i,v in pairs(recs[4]) do 
    if v.name == "box" then
      transition.to(v, {time = 2000, alpha = 0.25, transition = easing.inSine})
    else
      transition.to(v, {time = 2000, alpha = 1, transition = easing.inSine})
    end
  end
  createShine()
end

local function resetMiniGame()
  if miniGameScore > 50 and not secretActive then
    showSecret()
  end
  
  notes = {}
  miniGameScore = 0
end

local function calculateScore(clickX)
  local difference = math.abs(clickX - (centerX - screenWidth/3))
  local tolerance = 30
  
  if difference <= tolerance/2 then
    return 10, "perfect"
  elseif difference <= tolerance then
    return 8, "great"
  elseif difference <= tolerance*2 then
    return 6, "good"
  else
    return 4, "okay"
  end
end

local function scoreTxtPopup(acc, long)
  local text = display.newText(acc, centerX, screenHeight - screenHeight/5.75 + ((3-1)*100), boldFont, 55)
  text.alpha = 0
  
  local timein, delayin, delay
  
  if not long then
    timein = 250
    delayin = 100
    delay = 0
  else
    timein = 500
    delayin = 1000
    delay = 6000
  end
  
  if acc == "perfect" then
    text.fill = rgb("34ebcc")
  elseif acc == "great" then
    text.fill = rgb("34eb56")
  elseif acc == "good" then
    text.fill = rgb("c6eb34")
  elseif acc == "okay" then
    text.fill = rgb("917a44")
  elseif acc == "miss" then
    text.fill = rgb("914444")
  end
  
  transition.to(text, {transition = easing.inQuint,delay = delay, y = screenHeight - screenHeight/5.75 + ((2-1)*100), alpha = 1, time = timein, onComplete = function()
    transition.to(text, {transition = easing.outSine, delay = delayin, alpha = 0, time = timein, onComplete = function()
    if long then
      
      for i = 1,4 do
        noterings[i].img.state = "fading"
        transition.to(noterings[i].img, {transition = easing.outSine, time = 250, alpha = 0, onComplete = function()
          if i == 4 then
            for i = 1,4 do
              noterings[i].img:removeSelf()
            end
            noterings = {}
            starBtn.alpha = 0.3
            resetMiniGame()
            miniGameActive = false
          end
        end})
      end
      
    end
    end})
  end})
end

local function miniGameEnd()
  if miniGameScore < 50 then
    scoreTxtPopup("Score: "..miniGameScore.."/50", true)
  else
    scoreTxtPopup("Score: "..miniGameScore, true)
  end
end

local function hitNote(event)
  if event.phase ~= "began" then return end
  transition.to(event.target,{time = 100, transition = easing.outSine, alpha = 0})
  local scoreAdd, scoreTxt = calculateScore(event.target.x)
  miniGameScore = miniGameScore + scoreAdd
  scoreTxtPopup(scoreTxt, false)
end

local function moveNotes()
  if #notes == 0 or not miniGameActive then
    return
  end
  
  for i = 1,#notes do
    if notes[i] ~= 0 and notes[i] ~= 1 then
      if notes[i].delay <= 0 then
        notes[i].noteImg.x = notes[i].noteImg.x - 7
      else
        notes[i].delay = notes[i].delay - 1000/display.fps
      end
      if notes[i].noteImg.x < -100 then
        if notes[i].noteImg.alpha ~= 0 then
          scoreTxtPopup("miss", false)
        end
        notes[i].noteImg:removeSelf()
        notes[i] = 0
      end
    end
    
    if notes[#notes] == 0 then
      timer.performWithDelay(1500, miniGameEnd)
      audio.rewind({channel = 3})
      audio.stop(3)
      audio.play(waitingSound, {channel = 3, loops = 0})
      notes[#notes] = 1
    end
    
  end
  
  for i = 1,#noterings do
    noterings[i].img:toFront()
  end
  
end

local function createNote(pos,delaysec)
  local n = #notes+1
  notes[n] = {}
  notes[n].noteImg = display.newImageRect("assets/note.png", 90, 90)
  notes[n].noteImg.fill.effect = "filter.invert"
  notes[n].noteImg.x = centerX + screenWidth
  notes[n].noteImg.y = screenHeight - screenHeight/5.75 + ((pos-1)*100)
  notes[n].noteImg.alpha = 0.8
  notes[n].noteImg:addEventListener("tap", hitNote)
  notes[n].noteImg:addEventListener("touch", hitNote)
  notes[n].delaytime = delaysec
  local fullDelay = delaysec
  if #notes >= 1 then
    for i = 1,#notes-1 do
      fullDelay = fullDelay + notes[i].delaytime
    end
  end
  notes[n].delay = fullDelay
  notes[n].hit = false
end

local function createNoteRings()
  for i = 1,4 do
    noterings[i] = {}
    noterings[i].img = display.newImageRect("assets/notering.png", 90, 90)
    noterings[i].img.fill.effect = "filter.invert"
    noterings[i].img.x = centerX - screenWidth/3
    noterings[i].img.y = screenHeight - screenHeight/5.75 + ((i-1)*100)
    noterings[i].img.alpha = 0.3
    noterings[i].img.state = "occilating"
    
    local function transitionRing()
      if miniGameActive and noterings[i].img.state ~= "fading" then
        transition.to(noterings[i].img, {transition = easing.continuousLoop, time = 2000, alpha = 0.8, onComplete = function()
            transitionRing()
          end})
      end
    end
    
    transitionRing()
    
  end
end

local function startMiniGame()
  
  if miniGameActive or audio.isChannelPlaying(currentMainChannel) then
    return
  end

  audio.rewind({channel = 3})
  audio.stop(3)

  starBtn.alpha = 1

  miniGameActive = true
  createNoteRings()
  createNote(4,0)
  createNote(3,230)
  createNote(2,230)
  createNote(4,450)
  createNote(3,230)
  createNote(2,230)
  createNote(4,450)
  createNote(3,240)
  createNote(2,215)
  createNote(1,215)
  createNote(1,215)
  createNote(1,450)
  createNote(1,215)
  createNote(2,215)
  createNote(3,200)
  createNote(4,240)
  
  local function playJingle()
    audio.play(jingleSound, {channel = 3, loops = 0})
  end
  
  timer.performWithDelay(3000, playJingle)

end

-- track information

tracks = readSongs("playlists/"..currentPlaylist.."/discography.txt")
imgList = returnDir(imagesDir, true)
songList = returnDir(audioDir, true)

-- display objects

songList = loadSongs(songList)
durationList = getDurations(songList)
unloadSongs(songList)

musicPlayer = display.newGroup()
musicPlayer.anchorChildren = true
musicPlayer.x = centerX
musicPlayer.y = centerY
musicPlayer.alpha = 1

albumBlur = display.newImage(imgList[currentTrack], centerX, centerY)
applyBlur(albumBlur)
albumBlur.width = screenHeight
albumBlur.height = screenHeight
musicPlayer:insert(albumBlur)

albumBlurOffset = display.newImage(imgList[currentTrack], centerX, centerY)
applyBlur(albumBlurOffset)
albumBlurOffset.fill.effect = "filter.invert"
albumBlurOffset.width = screenHeight
albumBlurOffset.height = screenHeight
albumBlurOffset.alpha = 0.05
musicPlayer:insert(albumBlurOffset)

bgBlur = display.newRect(centerX, centerY, screenWidth, screenHeight)
applyGradient(bgBlur)
bgBlur.alpha = 0.75
musicPlayer:insert(bgBlur)

album = display.newImage(imgList[currentTrack], centerX, screenWidth*0.45)
album.anchorY = 0
album.width = albumSize
album.height = albumSize
musicPlayer:insert(album)

stateText = display.newText("NOW PLAYING", centerX, screenHeight/10, mainFont, 46)
stateText.alpha = 0.75
musicPlayer:insert(stateText)

songName = display.newText(tracks[currentTrack].name, centerX, album.height + screenWidth*0.565, boldFont, 55)
musicPlayer:insert(songName)

artistName = display.newText(tracks[currentTrack].artist, centerX, album.height + screenWidth*0.565 + 75, mainFont, 40)
artistName.alpha = 0.75
musicPlayer:insert(artistName)

-- control panel

controlPanel = display.newGroup()
controlPanel.anchorChildren = true

controlPanel.x = centerX
controlPanel.y = centerY + screenHeight*0.32

playBtn = display.newImageRect(controlPanel, buttonDir.."/play.png", 200, 200)
playBtn.x = centerX
playBtn.operation = "playPause"

pauseBtn = display.newImageRect(controlPanel, buttonDir.."/pause.png", 200, 200)
pauseBtn.x = centerX
pauseBtn.operation = "playPause"
pauseBtn.alpha = 0

forwardBtn = display.newImageRect(controlPanel, buttonDir.."/forward.png", 125, 125)
forwardBtn.x = screenWidth*0.7
forwardBtn.operation = "forward"

backBtn = display.newImageRect(controlPanel, buttonDir.."/back.png", 125, 125)
backBtn.x = screenWidth*0.3
backBtn.operation = "backward"

loopBtn = display.newImageRect(controlPanel, buttonDir.."/loop.png", 125, 125)
loopBtn.x = screenWidth*0.875
loopBtn.alpha = 0.3
loopBtn.operation = "loop"

shuffleBtn = display.newImageRect(controlPanel, buttonDir.."/shuffle.png", 125, 125)
shuffleBtn.x = screenWidth*0.125
shuffleBtn.alpha = 0.3
shuffleBtn.operation = "shuffle"

closeBtn = display.newImageRect(buttonDir.."/drop.png", 125, 125)
closeBtn.x = screenWidth*0.125
closeBtn.y = screenHeight/10
closeBtn.alpha = 1
closeBtn.operation = "closePlayer"
closeBtn.fill.effect = "filter.invert"
musicPlayer:insert(closeBtn)

menuBtn = display.newImageRect(buttonDir.."/menu.png", 125, 125)
menuBtn.x = screenWidth*0.875
menuBtn.y = screenHeight/10
menuBtn.alpha = 1
menuBtn.operation = "menu"
menuBtn.fill.effect = "filter.invert"
musicPlayer:insert(menuBtn)

xmenuBtn = display.newImageRect(buttonDir.."/close.png", 60, 60)
xmenuBtn.x = screenWidth*0.875
xmenuBtn.y = screenHeight/10
xmenuBtn.alpha = 0
xmenuBtn.operation = "menu"
xmenuBtn.fill.effect = "filter.invert"
musicPlayer:insert(xmenuBtn)

topMenu = display.newGroup()
topMenu.anchorChildren = true
topMenu.y = stateText.y * 1.5
topMenu.x = centerX

muteBtn = display.newImageRect(buttonDir.."/mute.png", 90, 90)
muteBtn.x = centerX - screenWidth*0.275
muteBtn.y = stateText.y * 1.5
muteBtn.alpha = 1
muteBtn.operation = "muteUnmute"
muteBtn.fill.effect = "filter.invert"
topMenu:insert(muteBtn)

unmuteBtn = display.newImageRect(buttonDir.."/sound.png", 90, 90)
unmuteBtn.x = centerX - screenWidth*0.275
unmuteBtn.y = stateText.y * 1.5
unmuteBtn.alpha = 0
unmuteBtn.operation = "muteUnmute"
unmuteBtn.fill.effect = "filter.invert"
topMenu:insert(unmuteBtn)

fadeBtn = display.newImageRect(buttonDir.."/fade.png", 75, 75)
fadeBtn.x = centerX + screenWidth*0.275
fadeBtn.y = stateText.y * 1.5
fadeBtn.alpha = 1
fadeBtn.operation = "fadeUnfade"
fadeBtn.fill.effect = "filter.invert"
topMenu:insert(fadeBtn)

unfadeBtn = display.newImageRect(buttonDir.."/solid.png", 75, 75)
unfadeBtn.x = centerX + screenWidth*0.275
unfadeBtn.y = stateText.y * 1.5
unfadeBtn.alpha = 0
unfadeBtn.operation = "fadeUnfade"
unfadeBtn.fill.effect = "filter.invert"
topMenu:insert(unfadeBtn)

progressBarBack = display.newRoundedRect(controlPanel, centerX, -screenWidth*0.2, albumSize, 15, 99)
progressBarBack.fill = {0}
progressBarBack.alpha = 0.2

progressBar = display.newRoundedRect(controlPanel, (screenWidth-albumSize)/2, -screenWidth*0.2, (songProgress/100)*progressBarBack.width, 15, 99)
progressBar.fill = {0}
progressBar.alpha = 0.5
progressBar.anchorX = 0

progressText = display.newText(controlPanel, formatDuration(songMs), (screenWidth-albumSize)/2, -screenWidth*0.2 + progressBar.height*2 , mainFont, 40)
progressText.fill = {0}
progressText.anchorX = 0
progressText.anchorY = 0

remainingTime = display.newText(controlPanel, "-"..formatDuration(durationList[currentTrack]), albumSize + (screenWidth-albumSize)/2, -screenWidth*0.2 + progressBar.height*2 , mainFont, 40)
remainingTime.fill = {0}
remainingTime.anchorX = 1
remainingTime.anchorY = 0

lightButtons(controlPanel)
addEvents(controlPanel)
musicPlayer:insert(controlPanel)

album:addEventListener("touch", detectSwipeChangeX)
album:addEventListener("touch", detectSwipeChangeY)
Runtime:addEventListener("enterFrame", updateProgress)

-- bottom bar

miniBar = display.newGroup()
miniBar.anchorChildren = true
miniBar.x = centerX
miniBar.y = screenHeight + miniBarHeight*2

miniBarMask = graphics.newMask("assets/miniBarMask.png")

miniAlbumBlur = display.newImage(imgList[currentTrack], centerX, centerY)
applyExtraBlur(miniAlbumBlur)
miniAlbumBlur.width = screenWidth
miniAlbumBlur.height = screenWidth*2
miniAlbumBlur:setMask(miniBarMask)
miniAlbumBlur.maskScaleX = 0.25
miniAlbumBlur.maskScaleY = 0.2
miniBar:insert(miniAlbumBlur)

miniBgBlur = display.newRect(centerX, centerY, screenWidth, screenWidth)
miniBgBlur.fill = {0.25}
miniBgBlur.alpha = 0.5
miniBgBlur:setMask(miniBarMask)
miniBgBlur.maskScaleX = 0.25
miniBgBlur.maskScaleY = 0.2
miniBar:insert(miniBgBlur)

miniSongName = display.newText(tracks[currentTrack].name, (screenWidth-albumSize)/1.75 + miniBarHeight*1.3, centerY - 23, boldFont, 45)
miniSongName.anchorX = 0
miniSongName.pause = 100
miniBar:insert(miniSongName)

titleContainer = display.newContainer(screenWidth/1.8, 100)
titleContainer.x = centerX
titleContainer.y = centerY - 23
titleContainer:insert(miniSongName, true)
miniBar:insert(titleContainer)

miniSongName.x = textStart

table.insert(titles, miniSongName)

miniAlbum = display.newImage(imgList[currentTrack], (screenWidth-albumSize)/1.75, centerY)
miniAlbum.anchorX = 0
miniAlbum.width = miniBarHeight
miniAlbum.height = miniBarHeight
miniBar:insert(miniAlbum)

miniArtistName = display.newText(tracks[currentTrack].artist, textStart*-1 + 8, centerY + 23, mainFont, 35)
miniArtistName.anchorX = 0
miniBar:insert(miniArtistName)

miniControlPanel = display.newGroup()
miniControlPanel.anchorChildren = true

miniControlPanel.x = screenWidth - (screenWidth-albumSize)
miniControlPanel.y = centerY

miniPlayBtn = display.newImageRect(miniControlPanel, buttonDir.."/play.png", 125, 125)
miniPlayBtn.operation = "playPause"

miniPauseBtn = display.newImageRect(miniControlPanel, buttonDir.."/pause.png", 125, 125)
miniPauseBtn.operation = "playPause"
miniPauseBtn.alpha = 0

lightButtons(miniControlPanel)
addEvents(miniControlPanel)
miniBar:insert(miniControlPanel)

miniProgressBarBack = display.newRoundedRect(centerX, centerY + miniBarHeight/1.6, albumSize, 10, 99)
miniProgressBarBack.fill = {0}
miniProgressBarBack.alpha = 0.2
miniBar:insert(miniProgressBarBack)

miniProgressBar = display.newRoundedRect((screenWidth-albumSize)/2, centerY + miniBarHeight/1.6, (songProgress/100)*miniProgressBarBack.width, 10, 99)
miniProgressBar.fill = {1}
miniProgressBar.alpha = 0.75
miniProgressBar.anchorX = 0
miniBar:insert(miniProgressBar)

miniBar:addEventListener("touch", detectSwipeChangeX)
miniBar:addEventListener("touch", detectSwipeChangeY)

-- menuing

musicPlayer.y = screenHeight*1.5

playListCoversList = returnDir(playlistCoversDir, true)
playlistNames = readSongs("assets/playlistNames.txt")

local accentColor = rgb(playlistNames[currentPlaylist].artist)

playlistMenu = display.newGroup()
playlistMenu.anchorChildren = true
playlistMenu.x = centerX
playlistMenu.y = centerY

playmenubg = display.newRect(centerX, centerY, screenWidth, screenHeight)
playmenubg.alpha = 0
playlistMenu:insert(playmenubg)

playlistbg = display.newRect(centerX, centerY, screenWidth, screenHeight)
playlistbg.fill = menuColor

createPlaylistViewer()

playlistTopGradient = display.newRect( centerX, 0, screenWidth, screenHeight*0.5 )
playlistTopGradient.anchorY = 0
playlistMenu:insert(playlistTopGradient)

playlistTopGradient2 = display.newRect( centerX, screenHeight*0.5 , screenWidth, screenWidth/8 )
playlistTopGradient2.anchorY = 0
playlistMenu:insert(playlistTopGradient2)

playlistGradient = {
  type = "gradient",
  color1 = { accentColor[1], accentColor[2], accentColor[3], 1 },
  color2 = { menuColor[1], menuColor[2], menuColor[3], 1 },
  direction = "bottom"
}
playlistGradient2 = {
  type = "gradient",
  color1 = { menuColor[1], menuColor[2], menuColor[3], 1  },
  color2 = { menuColor[1], menuColor[2], menuColor[3], 0 },
  direction = "bottom"
}
playlistTopGradient.fill = playlistGradient
playlistTopGradient2.fill = playlistGradient2

playlistAlbumShadow = display.newImage("assets/dropShadow.png", centerX, screenWidth*0.45/2)
playlistAlbumShadow.anchorY = 0
playlistAlbumShadow.width = albumSize/1.5
playlistAlbumShadow.height = albumSize/1.5
playlistAlbumShadow:scale(1.15, 1.15)
playlistMenu:insert(playlistAlbumShadow)

playlistAlbum = display.newImage(playListCoversList[currentPlaylist], centerX, screenWidth*0.45/2)
playlistAlbum.anchorY = 0
playlistAlbum.width = albumSize/1.5
playlistAlbum.height = albumSize/1.5
playlistMenu:insert(playlistAlbum)

playlistTitle = display.newText(playlistNames[currentPlaylist].name, (screenWidth-albumSize)/2, albumSize*1.075, boldFont, 75)
playlistTitle.anchorX = 0 
playlistMenu:insert(playlistTitle)

playlistDuration = display.newText(formatPlaylistTime(durationList), (screenWidth-albumSize)/2, playlistTitle.y + 75, mainFont, 40)
playlistDuration.anchorX = 0 
playlistDuration.alpha = 0.75
playlistMenu:insert(playlistDuration)

playPlaylistBtn = display.newImageRect(buttonDir.."/play.png", 165, 165)
playPlaylistBtn.x = screenWidth - (screenWidth-albumSize)/2
playPlaylistBtn.anchorX = 1
playPlaylistBtn.y = albumSize*1.1
playPlaylistBtn.fill.effect = "filter.invert"
playPlaylistBtn.operation = "playStopPlaylist"
playPlaylistBtn.name = "playPlaylistBtn"
playlistMenu:insert(playPlaylistBtn)

stopPlaylistBtn = display.newImageRect(buttonDir.."/stop.png", 165, 165)
stopPlaylistBtn.x = screenWidth - (screenWidth-albumSize)/2
stopPlaylistBtn.anchorX = 1
stopPlaylistBtn.y = albumSize*1.1
stopPlaylistBtn.operation = "playStopPlaylist"
stopPlaylistBtn.alpha = 0
stopPlaylistBtn.fill.effect = "filter.invert"
stopPlaylistBtn.name = "stopPlaylistBtn"
playlistMenu:insert(stopPlaylistBtn)

expandPlaylistBtn = display.newImageRect(buttonDir.."/expand.png", 80, 80)
expandPlaylistBtn.x = screenWidth - (screenWidth-albumSize)/2
expandPlaylistBtn.anchorX = 1
expandPlaylistBtn.y = screenHeight/10
expandPlaylistBtn.alpha = 0.3
expandPlaylistBtn.operation = "expandPlaylist"
expandPlaylistBtn.fill.effect = "filter.invert"
playlistMenu:insert(expandPlaylistBtn)

closePlaylistBtn = display.newImageRect(buttonDir.."/drop.png", 140, 140)
closePlaylistBtn.x = (screenWidth-albumSize)/2 - 25
closePlaylistBtn.rotation = 90
closePlaylistBtn.anchorX = 0.5
closePlaylistBtn.anchorY = 1
closePlaylistBtn.y = screenHeight/10
closePlaylistBtn.alpha = 1
closePlaylistBtn.operation = "closePlaylist"
closePlaylistBtn.fill.effect = "filter.invert"
playlistMenu:insert(closePlaylistBtn)

playPlaylistBtn:addEventListener("tap", btnTap)
stopPlaylistBtn:addEventListener("tap", btnTap)
closeBtn:addEventListener("tap", btnTap)
muteBtn:addEventListener("tap", btnTap)
unmuteBtn:addEventListener("tap", btnTap)
fadeBtn:addEventListener("tap", btnTap)
unfadeBtn:addEventListener("tap", btnTap)
menuBtn:addEventListener("tap", btnTap)
xmenuBtn:addEventListener("tap", btnTap)
expandPlaylistBtn:addEventListener("tap", btnTap)
closePlaylistBtn:addEventListener("tap", btnTap)

musicPlayer:toFront()

local options = {
    frames = {
      { x=0, y=0, width=36, height=64 },
      { x=40, y=0, width=36, height=64 },
      { x=80, y=0, width=36, height=64 },
      { x=124, y=0, width=36, height=64 },
      { x=168, y=0, width=64, height=64 }
    },
    sheetContentWidth = 232,
    sheetContentHeight = 64
}
local sliderSheet = graphics.newImageSheet( "assets/sliderSheet.png", options )

volumeSlider = widget.newSlider({
    x = centerX,
    y = stateText.y * 1.5,
    sheet = sliderSheet,
    leftFrame = 1,
    alpha = 0.5,
    middleFrame = 2,
    rightFrame = 3,
    fillFrame = 4,
    frameWidth = 36*1.25,
    frameHeight = 64*1.25,
    handleFrame = 5,
    handleWidth = 64*1.25,
    handleHeight = 64*1.25,
    width = screenWidth/2,
    value = 100 * currentVolume,
    listener = function(event)
      currentVolume = event.value/100
      audio.setVolume(event.value/100)
    end
})
topMenu:insert(volumeSlider)
musicPlayer:insert(topMenu)
topMenu.alpha = 0

-- home screen

menubg = display.newRect(centerX, centerY, screenWidth, screenHeight)
menubg.fill = menuColor

homeTitles[1] = display.newText(getWelcomeMessage(), (screenWidth-albumSize)/2, screenHeight/10, boldFont, 75)
homeTitles[1].anchorX = 0 

homeTxts[1] = display.newText("Your daily recommendations", (screenWidth-albumSize)/2, screenHeight/10 + homeSpacing, boldFont, 45)
homeTxts[1].anchorX = 0 
homeTxts[1].alpha = 0.5

homeRec1num = math.random(1,3)
homeRec2num = math.random(1,3)

repeat 
  homeRec2num = math.random(1,3)
until homeRec1num ~= homeRec2num

recs[1] = createHomeRec(screenWidth*0.27, homeTxts[1].y + homeSpacing*1.5, homeRec1num)
recs[2] = createHomeRec(screenWidth*0.73, homeTxts[1].y + homeSpacing*1.5, homeRec2num)

albumMask = graphics.newMask("assets/albumMask.png")

profilePlaylistBtn = display.newImageRect(buttonDir.."/profile.png", 95, 95)
profilePlaylistBtn.x = screenWidth - (screenWidth-albumSize)/2
profilePlaylistBtn.anchorX = 1
profilePlaylistBtn.y = screenHeight/10
profilePlaylistBtn.fill.effect = "filter.invert"

homeTitles[2] = display.newText("Made For You", (screenWidth-albumSize)/2, recs[1].box.y + homeSpacing*2, boldFont, 75)
homeTitles[2].anchorX = 0 

createPlaylistScroll()

homeTitles[3] = display.newText("Liked Songs", (screenWidth-albumSize)/2, playlistAlbumScrollView.y*1.25 + homeSpacing, boldFont, 75)
homeTitles[3].anchorX = 0

recs[3] = createHomeRec(screenWidth*0.27, homeTitles[3].y + homeSpacing*1.75, 4)
recs[4] = createHomeRec(screenWidth*0.73, homeTitles[3].y + homeSpacing*1.75, 5)

for i,v in pairs(recs[4]) do v.alpha = 0 end

local blockerGradient = {
    type = "gradient",
    color1 = { menuColor[1], menuColor[2], menuColor[3], 1  },
    color2 = { menuColor[1], menuColor[2], menuColor[3], 0 },
    direction = "right"
}

local blocker1 = display.newRect(0, centerY - screenWidth/20, screenWidth/10, screenHeight/3)
blocker1.anchorX = 0
blocker1.fill = blockerGradient

local blocker2 = display.newRect(screenWidth, centerY - screenWidth/20, screenWidth/10, screenHeight/3)
blocker2.anchorX = 0
blocker2.fill = blockerGradient
blocker2.rotation = 180

playlistbg:toFront()
playlistScrollView:toFront()
playlistMenu:toFront()

playlistMenu.anchorChildren = false
playlistMenu.x = 0
playlistMenu.y = 0
transition.to(playlistbg, {x = -screenWidth, time = 0, transition = easing.inCubic})
transition.to(playlistScrollView, {x = playlistScrollView.x-screenWidth, time = 0, transition = easing.inCubic})
transition.to(playlistMenu, {x = playlistMenu.x-screenWidth, time = 0, transition = easing.inCubic, onComplete = function()
  playlistMenu.anchorChildren = true
  playlistMenu.x = centerX-screenWidth*1.5
  playlistMenu.y = centerY
  viewState = "home"
end})

starBtn = display.newImageRect("assets/star.png", 90, 90)
starBtn.x = screenWidth - screenWidth*0.125
starBtn.y = screenHeight - screenHeight/10/1.75
starBtn.alpha = 0.3
starBtn.fill.effect = "filter.invert"
starBtn:addEventListener("tap", startMiniGame)

Runtime:addEventListener("enterFrame", moveTitles)
Runtime:addEventListener("enterFrame", moveNotes)

local bgTransition = display.newRect(centerX, centerY, screenWidth, screenHeight)
bgTransition.fill = menuColor

local bgLogoBlur = display.newImage("assets/noteLogoBlur.png")
bgLogoBlur.fill.effect = "filter.invert"
bgLogoBlur.x = centerX
bgLogoBlur.y = centerY
bgLogoBlur:scale(0.4,0.4)

local bgLogo = display.newImage("assets/noteLogo.png")
bgLogo.fill.effect = "filter.invert"
bgLogo.x = centerX
bgLogo.y = centerY
bgLogo:scale(0.4,0.4)

-- screen check

if screenWidth ~= 1125 or screenHeight ~= 2436 then
  local alertBg = display.newRect(centerX, centerY, screenWidth, screenHeight)
  alertBg.fill = {0}
  local alertText1 = display.newText("This screen resolution is not currently supported.", centerX, centerY - 22.5*(screenWidth/1080), native.systemFontBold, 40*(screenWidth/1080))
  local alertText2 = display.newText("Please switch to iphone X resolution.", centerX, centerY + 22.5*(screenWidth/1080), native.systemFontBold, 40*(screenWidth/1080))
  wrongDisplay = true
end

if not wrongDisplay then
  local transitionBg = easing.inOutQuad
  local transitionTime = 1000
  local transitionDelay = 2000
  
  transition.to(bgLogo, {time = transitionTime, delay = transitionDelay, xScale = 2, yScale = 2, alpha = 0, transition = transitionBg})
  transition.to(bgLogoBlur, {time = transitionTime, delay = transitionDelay, xScale = 2, yScale = 2, alpha = 0, transition = transitionBg})
  transition.to(bgTransition, {time = transitionTime, delay = transitionDelay, alpha = 0, transition = transitionBg})
end