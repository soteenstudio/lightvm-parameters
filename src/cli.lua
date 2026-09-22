-- src/cli.lua
package.path = package.path .. ";src/?.lua;./?.lua"
local compiler = require("compiler")

local function main()
    local inputFile = arg[1]
    local outputFile = arg[2]

    if not inputFile or not outputFile then
        print("❌ Penggunaan: lua cli.lua <input.lcof> <output.json>")
        return 1
    end

    local f = io.open(inputFile, "r")
    if not f then
        print("❌ File input '" .. inputFile .. "' tidak ditemukan!")
        return 1
    end
    local code = f:read("*all")
    f:close()

    print("⚙️ Mengompilasi " .. inputFile .. " ke " .. outputFile .. "...")

    local success, jsonOutput = pcall(compiler.compile, code)
    if not success then
        print("❌ Gagal Compile: " .. tostring(jsonOutput))
        return 1
    end

    local out = io.open(outputFile, "w")
    if not out then
        print("❌ Gagal membuka file output untuk ditulis!")
        return 1
    end
    local writeSuccess = out:write(jsonOutput)
    local closeSuccess = out:close()
    if not writeSuccess or not closeSuccess then
        print("❌ Gagal menulis file output!")
        return 1
    end

    print("✨ Sukses! Berhasil di-compile ke " .. outputFile)
    return 0
end

os.exit(main())
