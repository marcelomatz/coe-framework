-- Definições de grupos (job, gang) vindas do arquivo de configuração. O arquivo é a fonte da
-- verdade; este módulo valida, copia e serve as definições em memória.
Core.Groups = Core.Groups or {}

local NAME_PATTERN = '^[a-z][a-z0-9_]*$'
local MAX_NAME_LENGTH = 32
local MAX_TYPE_LENGTH = 16
local MAX_LABEL_LENGTH = 64
local MAX_GROUPS = 100
local MAX_GRADES = 64
local MAX_GRADE_VALUE = 255

local definitions = { types = {}, groups = {} }

function Core.Groups.IsValidName(value)
	return type(value) == 'string' and #value <= MAX_NAME_LENGTH and value:match(NAME_PATTERN) ~= nil
end

local function isValidType(value)
	return type(value) == 'string' and #value <= MAX_TYPE_LENGTH and value:match(NAME_PATTERN) ~= nil
end

local function isValidLabel(value)
	return type(value) == 'string' and #value >= 1 and #value <= MAX_LABEL_LENGTH and not value:find('%c')
end

local function isGradeValue(value)
	return type(value) == 'number' and value == math.floor(value) and value >= 0 and value <= MAX_GRADE_VALUE
end

local function normalizeGrades(rawGrades)
	if type(rawGrades) ~= 'table' then
		return nil
	end

	local grades = {}
	for grade, entry in pairs(rawGrades) do
		if not isGradeValue(grade) or type(entry) ~= 'table' or not isValidLabel(entry.label) then
			return nil
		end
		grades[#grades + 1] = { grade = grade, label = entry.label }
	end
	if #grades == 0 or #grades > MAX_GRADES then
		return nil
	end
	table.sort(grades, function(left, right)
		return left.grade < right.grade
	end)
	return grades
end

-- config = { Types = { 'job', 'gang' }, Groups = { police = { type, label, grades = { [0] = { label } } } } }
-- Substitui as definições atuais somente se tudo for válido.
function Core.Groups.SetDefinitions(config)
	if type(config) ~= 'table' or type(config.Types) ~= 'table' or type(config.Groups) ~= 'table' then
		return false, 'invalid_group_config'
	end

	local types = {}
	for _, groupType in ipairs(config.Types) do
		if not isValidType(groupType) then
			return false, 'invalid_group_type'
		end
		types[groupType] = true
	end
	if next(types) == nil then
		return false, 'invalid_group_type'
	end

	local groups = {}
	local count = 0
	for name, raw in pairs(config.Groups) do
		count = count + 1
		if count > MAX_GROUPS then
			return false, 'too_many_groups'
		end
		if not Core.Groups.IsValidName(name) or type(raw) ~= 'table' then
			return false, 'invalid_group_name'
		end
		if not types[raw.type] then
			return false, 'invalid_group_type'
		end
		if not isValidLabel(raw.label) then
			return false, 'invalid_group_label'
		end
		local grades = normalizeGrades(raw.grades)
		if not grades then
			return false, 'invalid_group_grades'
		end
		groups[name] = { name = name, type = raw.type, label = raw.label, grades = grades }
	end

	definitions = { types = types, groups = groups }
	return true
end

local function copyGroup(group)
	local grades = {}
	for index, grade in ipairs(group.grades) do
		grades[index] = { grade = grade.grade, label = grade.label }
	end
	return { name = group.name, type = group.type, label = group.label, grades = grades }
end

function Core.Groups.Get(name)
	local group = type(name) == 'string' and definitions.groups[name]
	if not group then
		return nil, 'group_not_found'
	end
	return copyGroup(group)
end

-- Lista ordenada por nome.
function Core.Groups.List()
	local names = {}
	for name in pairs(definitions.groups) do
		names[#names + 1] = name
	end
	table.sort(names)

	local result = {}
	for _, name in ipairs(names) do
		result[#result + 1] = copyGroup(definitions.groups[name])
	end
	return result
end

-- Rótulo do grade ou nil quando o grupo ou o grade não existem nas definições.
function Core.Groups.GetGradeLabel(name, grade)
	local group = type(name) == 'string' and definitions.groups[name]
	if not group then
		return nil, 'group_not_found'
	end
	for _, entry in ipairs(group.grades) do
		if entry.grade == grade then
			return entry.label
		end
	end
	return nil, 'grade_not_found'
end
