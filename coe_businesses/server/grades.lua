BusinessGrades = {}

local function text(value, max)
	if type(value) ~= 'string' then
		return nil
	end
	value = value:gsub('^%s+', ''):gsub('%s+$', '')
	if value == '' or #value > max or value:find('[%c<>]') then
		return nil
	end
	return value
end

function BusinessGrades.IsPermission(value)
	return type(value) == 'string' and #value <= 40 and value:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_]*$') ~= nil
end

-- Cargos de um negócio: { id, label, level, salary, permissions }, ordenados por nível (o menor é o cargo de entrada).
-- Retorna a lista limpa ou nil,erro. Lista vazia/ausente significa negócio sem cargos.
function BusinessGrades.Normalize(raw, limits)
	if raw == nil then
		return {}
	end
	if type(raw) ~= 'table' or #raw > limits.MaxGrades then
		return nil, 'invalid_grades'
	end
	local grades, seenId, seenLevel = {}, {}, {}
	for _, entry in ipairs(raw) do
		if type(entry) ~= 'table' then
			return nil, 'invalid_grades'
		end
		local id = type(entry.id) == 'string' and entry.id:match('^[a-z][a-z0-9_]*$')
		local label = text(entry.label, 32)
		local level = math.tointeger(entry.level)
		local salary = math.tointeger(entry.salary == nil and 0 or entry.salary)
		if not id or #id < 2 or #id > 24 or not label or not level or level < 0 or level > limits.MaxGradeLevel
			or not salary or salary < 0 or salary > limits.MaxSalary or seenId[id] or seenLevel[level] then
			return nil, 'invalid_grades'
		end
		local permissions, seenPermission = {}, {}
		if entry.permissions ~= nil then
			if type(entry.permissions) ~= 'table' or #entry.permissions > limits.MaxPermissionsPerGrade then
				return nil, 'invalid_grades'
			end
			for _, permission in ipairs(entry.permissions) do
				if not BusinessGrades.IsPermission(permission) then
					return nil, 'invalid_grades'
				end
				if not seenPermission[permission] then
					seenPermission[permission] = true
					permissions[#permissions + 1] = permission
				end
			end
			table.sort(permissions)
		end
		seenId[id], seenLevel[level] = true, true
		grades[#grades + 1] = { id = id, label = label, level = level, salary = salary, permissions = permissions }
	end
	table.sort(grades, function(a, b)
		return a.level < b.level
	end)
	return grades
end

function BusinessGrades.Find(grades, id)
	for _, grade in ipairs(grades or {}) do
		if grade.id == id then
			return grade
		end
	end
	return nil
end

-- Define o cargo de cada funcionário: sem cargo informado, usa o de entrada; cargo inexistente é erro.
-- Sem cargos no negócio, o funcionário fica sem cargo.
function BusinessGrades.Assign(grades, staff)
	for _, member in ipairs(staff) do
		if #grades == 0 then
			member.grade = nil
		elseif member.grade == nil then
			member.grade = grades[1].id
		elseif not BusinessGrades.Find(grades, member.grade) then
			return nil, 'invalid_staff_grade'
		end
	end
	return true
end

-- Cargo de um personagem na equipe do negócio (nil se não é funcionário ou não há cargos).
function BusinessGrades.Of(business, characterId)
	if type(business) ~= 'table' or characterId == nil then
		return nil
	end
	for _, member in ipairs(business.staff or {}) do
		if tostring(member.characterId) == tostring(characterId) then
			return BusinessGrades.Find(business.grades, member.grade)
		end
	end
	return nil
end

-- Mudanças de equipe entre duas versões do negócio: { characterId, change = 'added'|'removed'|'grade', grade }.
function BusinessGrades.Diff(before, after)
	local changes, old = {}, {}
	for _, member in ipairs(before and before.staff or {}) do
		old[tostring(member.characterId)] = member
	end
	local seen = {}
	for _, member in ipairs(after and after.staff or {}) do
		local key = tostring(member.characterId)
		seen[key] = true
		if not old[key] then
			changes[#changes + 1] = { characterId = key, change = 'added', grade = member.grade }
		elseif old[key].grade ~= member.grade then
			changes[#changes + 1] = { characterId = key, change = 'grade', grade = member.grade }
		end
	end
	for key in pairs(old) do
		if not seen[key] then
			changes[#changes + 1] = { characterId = key, change = 'removed' }
		end
	end
	table.sort(changes, function(a, b)
		return a.characterId < b.characterId
	end)
	return changes
end

-- Se as definições de cargo mudaram (nome, nível, salário ou permissões).
function BusinessGrades.Differ(before, after)
	before, after = before or {}, after or {}
	if #before ~= #after then
		return true
	end
	for index, a in ipairs(before) do
		local b = after[index]
		if a.id ~= b.id or a.label ~= b.label or a.level ~= b.level or a.salary ~= b.salary
			or table.concat(a.permissions, ',') ~= table.concat(b.permissions, ',') then
			return true
		end
	end
	return false
end

-- Permissões efetivas de um personagem: o dono (com ownerAccess) tem todas; a equipe tem as do seu cargo.
function BusinessGrades.Can(business, characterId, permission, isOwner)
	if isOwner then
		return true
	end
	local grade = BusinessGrades.Of(business, characterId)
	if not grade then
		return false
	end
	for _, entry in ipairs(grade.permissions) do
		if entry == permission then
			return true
		end
	end
	return false
end
