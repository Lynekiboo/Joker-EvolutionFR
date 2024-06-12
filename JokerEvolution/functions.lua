local function has_joker(e)
	for k, v in pairs(G.jokers.cards) do
		if v.ability.set == 'Joker' and v.config.center.key == e then 
			return k
		end
	end
	return -1
end

function JokerEvolution.evolutions:add_evolution(joker, evolved_joker, amount, carry_stat)
    table.insert(self, {key = joker, evo = evolved_joker, amount = amount, carry_stat = carry_stat})
	sendDebugMessage(G.P_CENTERS[joker].amount)
end

function has_evo(c)
	for _, joker in ipairs(JokerEvolution.evolutions) do
		if c.key == joker.key then
			return true
		end
	end
	return false
end

function Card:decrement_evo_condition(amount)
	local amount = amount or 1
	if self.ability.amount then
		self.ability.amount = self.ability.amount - amount
		if self.ability.amount <= 0 and not self.ability.can_evolve then
			self.ability.can_evolve = true
		end
	end
end

function Card:can_evolve_card()
	for _, joker in ipairs(JokerEvolution.evolutions) do
		local exists = false
		local all_jokers = true
		if G.jokers and G.jokers.cards and not (has_joker(joker.key) > -1) then
			all_jokers = false
		end
		if joker.key == self.config.center.key then
			exists = true
		end
		if not self.debuff and exists and all_jokers and self.ability.can_evolve then
			return true
		end
	end 
    return false
end

function Card:get_card_evolution()
	if not self.config then print(tprint(self)); return false end --Cryptid failsafe
	for _, evo in ipairs(JokerEvolution.evolutions) do
		if evo.key == self.config.center.key then
			return evo
		end
	end 
    return false
end

function Card:evolve_card()
	G.CONTROLLER.locks.selling_card = true
    stop_use()
    local area = self.area
    G.CONTROLLER:save_cardarea_focus('jokers')

    if self.children.use_button then self.children.use_button:remove(); self.children.use_button = nil end
    if self.children.sell_button then self.children.sell_button:remove(); self.children.sell_button = nil end

	local final_evo = nil
	for _, joker in ipairs(JokerEvolution.evolutions) do
		if joker.key == self.config.center.key then
			final_evo = joker
			break
		end
	end

	if final_evo ~= nil then
		if G.jokers and G.jokers.cards and #G.jokers.cards > 0 then
			for i = 0, #G.jokers.cards do
				if G.jokers.cards[i] ~= nil then
					G.jokers.cards[i]:calculate_joker({evolution = true})
				end
			end
		end
		G.E_MANAGER:add_event(Event({trigger = 'after',delay = 0.2, func = function()
			play_sound('whoosh1')
			self:juice_up(0.3, 0.4)
			return true
		end}))
		delay(0.2)
		G.E_MANAGER:add_event(Event({trigger = 'immediate', func = function()
			local j_evo = nil
			if self.edition then
				j_evo = create_card_alt('Joker', G.jokers, nil, nil, nil, nil, final_evo.evo, nil, true, self.edition)
			else
				j_evo = create_card_alt('Joker', G.jokers, nil, nil, nil, nil, final_evo.evo)
			end

			if self.ability.eternal then
				j_evo.ability.eternal = true
			end
			if self.ability.perishable then
				j_evo.ability.perishable = true
				j_evo.ability.perish_tally = self.ability.perish_tally or G.GAME.perishable_rounds
			end
			if self.ability.rental then
				j_evo.ability.rental = true
			end
			if self.pinned then
				j_evo.pinned = true
			end

			if final_evo.carry_stat then
				for _, val in ipairs(final_evo.carry_stat) do
					if self[val] then
						j_evo[val] = self[val]
					end
					if self.ability[val] ~= nil then
						j_evo.ability[val] = self.ability[val]
					end
					if self.ability.extra and type(self.ability.extra) ~= "table" then
						j_evo.ability.extra = self.ability.extra
					elseif self.ability.extra and self.ability.extra[val] ~= nil then
						j_evo.ability.extra[val] = self.ability.extra[val]
					end
				end
			end

			self:start_dissolve({G.C.GOLD})
			
			delay(0.1)

			j_evo:add_to_deck()
			G.jokers:emplace(j_evo)
			play_sound('explosion_release1')

			delay(0.1)
			G.E_MANAGER:add_event(Event({trigger = 'after',delay = 0.3, blocking = false,
			func = function()
				G.E_MANAGER:add_event(Event({trigger = 'immediate',
				func = function()
					G.E_MANAGER:add_event(Event({trigger = 'immediate',
					func = function()
						G.CONTROLLER.locks.selling_card = nil
						G.CONTROLLER:recall_cardarea_focus(area == G.jokers and 'jokers' or 'consumeables')
					return true
					end}))
				return true
				end}))
			return true
			end}))
			return true
		end}))
	end

	G.CONTROLLER.locks.selling_card = nil
	G.CONTROLLER:recall_cardarea_focus('jokers')
end

function Card:calculate_evo(context)
	if self:get_card_evolution() and not context.blueprint then
		local obj = self.config.center
		local evol = self:get_card_evolution()
		if not obj.calculate_evo and G.P_CENTERS[evol.evo].calculate_evo then
			obj.calculate_evo = G.P_CENTERS[evol.evo].calculate_evo
		end
		if obj and obj.calculate_evo and type(obj.calculate_evo) == 'function' then
			local o = obj:calculate_evo(self, context)
			if o then return o end
		end
	end
end

function set_evo_tooltip(_c)
	for _, joker in ipairs(JokerEvolution.evolutions) do
		if _c.key == joker.key then
			if G.jokers and G.jokers.cards and #G.jokers.cards > 0 then
				for i = 1, #G.jokers.cards do
					if G.jokers.cards[i].config.center.key == joker.key then
						return {key = "je_" .. joker.key, set = "Other", vars = {joker.amount - math.max(G.jokers.cards[i].ability.amount, 0), joker.amount}}
					end
				end
			end
			return {key = "je_" .. joker.key, set = "Other", vars = {0, joker.amount}}
		end
	end
end

G.FUNCS.evolve_card = function(e)
    local card = e.config.ref_table
    card:evolve_card()
end

G.FUNCS.can_evolve_card = function(e)
    if e.config.ref_table:can_evolve_card() then 
        e.config.colour = G.C.GOLD
        e.config.button = 'evolve_card'
    else
      	e.config.colour = G.C.UI.BACKGROUND_INACTIVE
      	e.config.button = nil
    end
end

function create_card_alt(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append, edition_append, forced_edition)
    local area = area or G.jokers
    local center = G.P_CENTERS.b_red
        

    --should pool be skipped with a forced key
    if not forced_key and soulable and (not G.GAME.banned_keys['c_soul']) then
        if (_type == 'Tarot' or _type == 'Spectral' or _type == 'Tarot_Planet') and
        not (G.GAME.used_jokers['c_soul'] and not next(find_joker("Showman")))  then
            if pseudorandom('soul_'.._type..G.GAME.round_resets.ante) > 0.997 then
                forced_key = 'c_soul'
            end
        end
        if (_type == 'Planet' or _type == 'Spectral') and
        not (G.GAME.used_jokers['c_black_hole'] and not next(find_joker("Showman")))  then 
            if pseudorandom('soul_'.._type..G.GAME.round_resets.ante) > 0.997 then
                forced_key = 'c_black_hole'
            end
        end
    end

    if _type == 'Base' then 
        forced_key = 'c_base'
    end



    if forced_key and not G.GAME.banned_keys[forced_key] then 
        center = G.P_CENTERS[forced_key]
        _type = (center.set ~= 'Default' and center.set or _type)
    else
        local _pool, _pool_key = get_current_pool(_type, _rarity, legendary, key_append)
        center = pseudorandom_element(_pool, pseudoseed(_pool_key))
        local it = 1
        while center == 'UNAVAILABLE' do
            it = it + 1
            center = pseudorandom_element(_pool, pseudoseed(_pool_key..'_resample'..it))
        end

        center = G.P_CENTERS[center]
    end

    local front = ((_type=='Base' or _type == 'Enhanced') and pseudorandom_element(G.P_CARDS, pseudoseed('front'..(key_append or '')..G.GAME.round_resets.ante))) or nil

    local card = Card(area.T.x + area.T.w/2, area.T.y, G.CARD_W, G.CARD_H, front, center,
    {bypass_discovery_center = area==G.shop_jokers or area == G.pack_cards or area == G.shop_vouchers or (G.shop_demo and area==G.shop_demo) or area==G.jokers or area==G.consumeables,
     bypass_discovery_ui = area==G.shop_jokers or area == G.pack_cards or area==G.shop_vouchers or (G.shop_demo and area==G.shop_demo),
     discover = area==G.jokers or area==G.consumeables, 
     bypass_back = G.GAME.selected_back.pos})
    if card.ability.consumeable and not skip_materialize then card:start_materialize() end

    if _type == 'Joker' then
        if G.GAME.modifiers.all_eternal then
            card:set_eternal(true)
        end
        if (area == G.shop_jokers) or (area == G.pack_cards) then 
            local eternal_perishable_poll = pseudorandom((area == G.pack_cards and 'packetper' or 'etperpoll')..G.GAME.round_resets.ante)
            if G.GAME.modifiers.enable_eternals_in_shop and eternal_perishable_poll > 0.7 then
                card:set_eternal(true)
            elseif G.GAME.modifiers.enable_perishables_in_shop and ((eternal_perishable_poll > 0.4) and (eternal_perishable_poll <= 0.7)) then
                card:set_perishable(true)
            end
            if G.GAME.modifiers.enable_rentals_in_shop and pseudorandom((area == G.pack_cards and 'packssjr' or 'ssjr')..G.GAME.round_resets.ante) > 0.7 then
                card:set_rental(true)
            end
        end

		if edition_append then
			if forced_edition == nil then
				local edition = poll_edition('edi'..(key_append or '')..G.GAME.round_resets.ante)
				card:set_edition(edition)
			else
				card:set_edition(forced_edition)
			end
			check_for_unlock({type = 'have_edition'})
		end
    end
    return card
end

return