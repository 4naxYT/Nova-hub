
# Usage and download instructions in LuaU 

```lua

-- Uses in-built functions found in roblox executors

-- creates audio folder is not there already
if not isfolder("Audio") then
    makefolder("Audio")
end

-- makes the function for safely creating the music file
local function create_musicfile(path,link)
    if not isfile(tostring(path)) then
        writefile(tostring(path), game:HttpGet(tostring(link)))
    end
end

-- create the music file in Audio folder
create_musicfile("Audio/Private Pure Love Train [JJK].mp3","https://raw.githubusercontent.com/4naxYT/Nova-hub/refs/heads/main/Featured%20Songs/Admiring%20You%20-%20Private%20Pure%20Love%20Train%20%5BJJK%5D.mp3")


```
