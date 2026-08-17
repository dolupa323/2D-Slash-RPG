-- Prototype-only: per UpsideEngine's install guide "An important step" —
-- NetworkingService and other services depend on the server requiring the
-- engine at startup, even if nothing server-side is used yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.packages

local UpsideEngine = require(packages.UpsideEngine)
print("Upside Engine version: " .. UpsideEngine.Version)
