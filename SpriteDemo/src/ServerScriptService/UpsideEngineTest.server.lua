-- Prototype-only: verifies the SERVER-AUTHORITATIVE replication path — the
-- pattern the docs use for NPCs/world objects (server creates + keeps
-- authority by default, object auto-replicates to clients). The previous
-- version of this script tried SceneManager:FindByName() to "find" the
-- client's scene from the server, which isn't a supported flow — a client's
-- Scene only exists on that client. The server must create its OWN Scene
-- and object; the client picks it up via the "Build" event (see
-- UpsideEngineTest.client.lua) and attaches it to its own local scene.
-- Safe to delete once the evaluation is done either way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpsideEngine = require(ReplicatedStorage.packages.UpsideEngine)

-- Wait a bit so the client's Build listener is definitely registered first
-- (ruling out a startup race as the cause if the client never sees this).
task.wait(3)

local serverScene = UpsideEngine.new("Scene")
serverScene:SetName("ServerWorld")
serverScene:Enable()

local marker = UpsideEngine.new("StaticObject")
marker:SetScene(serverScene)
marker.Instance.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
marker.Instance.BackgroundTransparency = 0
marker.Instance.Size = UDim2.fromOffset(80, 80)
marker.Instance.Position = UDim2.fromOffset(900, 600)
marker.Instance.ZIndex = 50

print("UpsideEngineTest(server): server-owned scene + marker created, should auto-replicate to clients via the 'Build' event")
