-- The content of this file is AUTO-GENERATED
-- You can update it at https://www.curseforge.com/wow/addons/brokeranything/localization
local ADDON_NAME, _ = ...
local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale(ADDON_NAME, "enUS", true, true)

-- Allow to use the L table as a function with substitution
-- e.g. L("I'm ${age} years old!", {age = 29})
do
	local _L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
	local LMetatable = getmetatable(_L)
	local newMetatable = {
		__index = LMetatable.__index,
		__newindex = LMetatable.__newindex,
		__call = function(self, locale, tab)
			return (self[locale]:gsub('($%b{})', function(w)
				return tab[w:sub(3, -2)] or w
			end))
		end
	}
	setmetatable(_L, newMetatable)
end

if L then
	--@debug@
	L["DOC_CUSTOM_INITIALIZATION"] = [[This script runs at the initialization of the broker.
It will be called as:

|cFF42A5F5OnInitialization|r(|cFF4CAF50broker|r)

- [|cFF4CAF50broker|r] Is the LibDataBroker table.]]

	L["DOC_CUSTOM_ON_EVENT"] = [[This script will be called by every event registered by this broker (Configuration > Events).
It will be called as:

|cFF42A5F5OnEvent|r(|cFF4CAF50broker|r, |cFF4CAF50event |r[, |cFF4CAF50...|r])

- [|cFF4CAF50broker|r] Is the LibDataBroker table.
- [|cFF4CAF50event|r] Is the Event that triggered it.
- [|cFF4CAF50...|r] Are the arguments the event supplies.]]

	L["DOC_CUSTOM_TOOLTIP"] = [[This script is called when the mouse is over the broker.
It will be called as:

|cFF42A5F5OnTooltip|r(|cFF4CAF50tooltip|r, |cFF4CAF50broker|r)

- [|cFF4CAF50tooltip|r] Is the wow Tooltip.
- [|cFF4CAF50broker|r] Is the LibDataBroker table.]]

	L["DOC_CUSTOM_ON_CLICK"] = [[This script is called when the broker is clicked.
It will be called as:

|cFF42A5F5OnClick|r(|cFF4CAF50frame|r, |cFF4CAF50button|r, |cFF4CAF50broker|r)

- [|cFF4CAF50frame|r] Is the frame clicked.
- [|cFF4CAF50button|r] Is the mouse button used to click this frame.
- [|cFF4CAF50broker|r] Is the LibDataBroker table.]]

	--@end-debug@
	--@localization(locale="enUS", format="lua_additive_table", same-key-is-true=true)@

	if GetLocale() == "enUS" or GetLocale() == "enGB" then
		return
	end
end

L = AceLocale:NewLocale(ADDON_NAME, "ptBR")
if L then
	--@localization(locale="ptBR", format="lua_additive_table")@
	--@debug@
	L["Click to open the UI"] = "Clique para abrir a interface"
	L["Show minimap button"] = "Exibir botão no minimapa"
	L["Show config UI"] = "Exibir interface de configuração"
	L["Invalid ID! (${id})"] = "ID inválido! (${id})"
	L["Already added! (${id})"] = "Já adicionado! (${id})"
	L["No currency with id '${id}' found!"] = "Nenhuma moeda com id '${id}' encontrada!"
	L["No item with id '${id}' found!"] = "Nenhum item com id '${id}' encontrado!"
	L["Using the existing data broker: "] = "Utilizando o data broker existente: "
	L["This session:"] = "Nesta sessão:"
	L["Current:"] = "Atual:"
	L["Maximum:"] = "Máximo:"
	L["Currency"] = "Moeda"
	L["You can drag & drop items here!"] = "Você pode arrastar e soltar itens aqui!"
	L["Add"] = "Adicionar"
	L["Remove"] = "Remover"
	L["Reload UI!"] = "Recarregue a UI!"
	L["Reload UI to take effect!"] = "Recarregue a interface para surtir efeito!"
	L["BA (currency) - "] = "BA (moeda) - "
	L["BA (item) - "] = "BA (item) - "
	L["BA (custom) - "] = "BA (personalizado) - "
	L["Item"] = "Item"
	L["Bag:"] = "Bolsa:"
	L["Bank:"] = "Banco:"
	L["Total:"] = "Total:"
	L["Custom"] = "Personalizado"
	L["Enable"] = "Habilitar"
	L["Configuration"] = "Configuração"
	L["Events"] = "Eventos"
	L["Interval (seconds)"] = "Intervalo (segundos)"
	L["Initialization"] = "Inicialização"

	L["DOC_CUSTOM_INITIALIZATION"] = [[Esse script é executado na inicialização do broker.
Ele será chamado como:

|cFF42A5F5OnInitialization|r(|cFF4CAF50broker|r)

- [|cFF4CAF50broker|r] É a tabela LibDataBroker.]]

	L["DOC_CUSTOM_ON_EVENT"] = [[Esse script é chamado por todos eventos registrados neste broker (Configurações > Eventos).
Ele será chamado como:

|cFF42A5F5OnEvent|r(|cFF4CAF50broker|r, |cFF4CAF50event |r[, |cFF4CAF50...|r])

- [|cFF4CAF50broker|r] É a tabela LibDataBroker.
- [|cFF4CAF50event|r] É o evento que o disparou.
- [|cFF4CAF50...|r] São os argumentos fornecidos pelo evento.]]

	L["DOC_CUSTOM_TOOLTIP"] = [[Esse script é executado quando o mouse está sobre o broker.
Ele será chamado como:

|cFF42A5F5OnTooltip|r(|cFF4CAF50tooltip|r, |cFF4CAF50broker|r)

- [|cFF4CAF50tooltip|r] É o Tooltip do wow.
- [|cFF4CAF50broker|r] É a tabela LibDataBroker.]]

	L["DOC_CUSTOM_ON_CLICK"] = [[Este script é executado quando o broker é clicado.
Ele será chamado como:

|cFF42A5F5OnClick|r(|cFF4CAF50frame|r, |cFF4CAF50button|r, |cFF4CAF50broker|r)

- [|cFF4CAF50frame|r] É o frame clicado.
- [|cFF4CAF50button|r] É o botão do mouse utilizado para clicar neste frame.
- [|cFF4CAF50broker|r] É a tabela LibDataBroker.]]

	L['Are you sure you want to remove "${name}"?\nAll of its configurations will be lost!'] = 'Tem certeza de que deseja remover "${name}"?\nTodas as suas configurações serão perdidas!'
	L["Rename"] = "Renomear"
	L['Are you sure you want to rename "${name}" to "${newName}"?'] = 'Tem certeza de que deseja renomear "${name}" para "${newName}"?'
	L["Share"] = "Compartilhar"
	L["Export"] = "Exportar"
	L["Import"] = "Importar"
	L["BrokerAnything - Import"] = "BrokerAnything - Importar"
	L["Name"] = "Nome"
	L["Importing '${broker}' from '${char}'"] = "Importando '${broker}' de '${char}'"
	L["Broker '${broker}' already exists!"] = "O Broker '${broker}' já existe!"
	L["Link"] = "Link"
	L["Click here to insert a link this broker in the chat!"] = "Clique aqui para inserir um link para esse broker no chat!"
	L["Yes"] = "Sim"
	L["No"] = "Não"
	L["Has Reward Pending!"] = "Possui recompensa pendente!"
	L["Standing:"] = "Situação atual:"
	L["Reputation:"] = "Reputação:"
	L["At war:"] = "Em Guerra"
	L["Reputation"] = "Reputação"
	L["Show value"] = "Mostrar valor"
	L["Hide maximun"] = "Esconder máximo"
	L["Show balance"] = "Mostrar saldo"
	L["Icon"] = "Icone"
	L["Name/Icon"] = "Nome/Icone"
	L["Reset session balance"] = "Redefinir o saldo da sessão"
	L["Minimap Broker"] = "Broker do Minimapa"
	L["Minimap broker configuration"] = "Configurações do Broker do minimapa"
	L["Format large numbers"] = "Formatar números grandes"
	--@end-debug@

	return
end

L = AceLocale:NewLocale(ADDON_NAME, "frFR")
if L then
	--@localization(locale="frFR", format="lua_additive_table")@
	return
end

L = AceLocale:NewLocale(ADDON_NAME, "deDE")
if L then
	--@localization(locale="deDE", format="lua_additive_table")@
	return
end

L = AceLocale:NewLocale(ADDON_NAME, "itIT")
if L then
	--@localization(locale="itIT", format="lua_additive_table")@
	return
end

L = AceLocale:NewLocale(ADDON_NAME, "esES")
if L then
	--@localization(locale="esES", format="lua_additive_table")@
	return
end

L = AceLocale:NewLocale(ADDON_NAME, "esMX")
if L then
	--@localization(locale="esMX", format="lua_additive_table")@
	return
end

L = AceLocale:NewLocale(ADDON_NAME, "ruRU")
if L then
	--@localization(locale="ruRU", format="lua_additive_table")@
	return
end






