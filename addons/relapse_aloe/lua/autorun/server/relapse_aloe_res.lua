local files = {
	"models/srp/prop_pbucket.mdl",
	"models/srp/prop_pbucket.dx80.vtx",
	"models/srp/prop_pbucket.dx90.vtx",
	"models/srp/prop_pbucket.vvd",
	"models/srp/prop_pbucket.phy",
	"models/srp/prop_cocaleaves.mdl",
	"models/srp/prop_cocaleaves.dx80.vtx",
	"models/srp/prop_cocaleaves.dx90.vtx",
	"models/srp/prop_cocaleaves.vvd",
	"models/srp/prop_cocaleaves.phy",
	"materials/models/srp/prop_pbucket.vmt",
	"materials/models/srp/prop_pbucket.vtf",
	"materials/models/srp/prop_cocaleaves.vmt",
	"materials/models/srp/prop_cocaleaves.vtf",
	"materials/models/srp/prop_cocastem.vmt",
	"materials/models/srp/prop_cocastem.vtf"
}

for i = 1, #files do
	resource.AddSingleFile(files[i])
end
