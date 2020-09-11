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
			return (self[locale]:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
		end
	}
	setmetatable(_L, newMetatable)
end

if L then
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
	L[
	[[Type your lua script here!
This script runs at the initialization of the broker. It will be called as function(broker) where:
[broker] is the LibDataBroker table]]
	] = [[Escreva seu código lua aqui!
Esse script é executado na inicialização do broker. Ele será chamado como function(broker) aonde:
[broker] é a tabela LibDataBroker]]
	L[
	[[Type your lua script here!
This script runs on every event. It will be called as function(broker, event [, ...]) where:
[broker] is the LibDataBroker table
[event] is the Event that triggered it
[...] the arguments the event supplies]]
	] = [[Escreva seu código lua aqui!
Esse script é executado em todos eventos. Ele será chamado como function(broker, event [, ...]) aonde:
[broker] é a tabela LibDataBroker
[event] é o evento que o disparou
[...] são os argumentos fornecidos pelo evento]]
	L[
	[[Type your lua script here!
This script is called when the mouse is over the broker. It will be called as function(tooltip) where:
[tooltip] is the wow Tooltip]]
	] = [[Escreva seu código lua aqui!
Esse script é executado quando o mouse está sobre o broker. Ele será chamado como function(tooltip) aonde:
[tooltip] é o Tooltip do wow]]
	L[
	[[Type your lua script here!
This script is called when the broker is clicked.]]
	] = [[Escreva seu código lua aqui!
Este script é executado quando o broker é clicado.]]

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






