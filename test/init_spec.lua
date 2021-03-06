-- native solution
local uppercase = require("uppercase")

describe("uppercase", function()
    describe("to_uppercase", function()
        it("should throw if text is not a string", function()
            local ok, err = pcall(uppercase.to_uppercase, { "not a string" })

            assert.falsy(ok)
            assert.truthy(err)
            assert.truthy(err:find("requires a string"))
        end)
    end)
end)
