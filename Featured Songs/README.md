
# Usage and download instructions in LuaU 

```lua

if not isfolder("Audio") then
    makefolder("Audio")
end

local function create_musicfile(path,link)
    if not isfile(tostring(path)) then
        writefile(tostring(path), game:HttpGet(tostring(link)))
    end
end

create_musicfile("Audio/Private Pure Love Train [JJK].mp3","https://raw.githubusercontent.com/4naxYT/Nova-hub/refs/heads/main/Featured%20Songs/Admiring%20You%20-%20Private%20Pure%20Love%20Train%20%5BJJK%5D.mp3")


```
