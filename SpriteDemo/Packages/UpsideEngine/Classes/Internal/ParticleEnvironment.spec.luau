local ParticleEnvironment = require(script.Parent.ParticleEnvironment)
return function()
	describe("Constructor .new()", function()
		it("should create a new ObjectEnvironment object", function()
			local newObjectEnvironment = ParticleEnvironment.new()
			expect(newObjectEnvironment).to.be.ok()
		end)
	end)
end
