class_name Economy
extends RefCounted
## Coin: what things cost and what the currency is called (data/economy.json), plus the
## prices on objects ("price", paid each time something is used) and building costs ("cost",
## paid once when it is put up and half refunded when it is taken down).
##
## Wages are the money coming in (jobs.json); meals, bread, ale and building are the money
## going out. Taxes and rent arrive with the medieval layer.


static func config() -> Dictionary:
	return DataRegistry.get_def("economy", "economy")


static func symbol() -> String:
	return str(config().get("symbol", "d"))


## "12d".
static func format(amount: int) -> String:
	return "%d%s" % [amount, symbol()]


static func start_coins() -> int:
	return int(config().get("start_coins", 0))


## A random purse for a townsperson.
static func npc_start_coins(rng: RandomNumberGenerator) -> int:
	var range_: Array = config().get("npc_start_coins", [0, 0])
	return rng.randi_range(int(range_[0]), int(range_[1]))


## What using an object costs each time (a tavern meal), 0 if it is free.
static func price(object_def_id: String) -> int:
	return int(DataRegistry.get_def("objects", object_def_id).get("price", 0))


static func object_cost(object_def_id: String) -> int:
	return int(DataRegistry.get_def("objects", object_def_id).get("cost", 0))


static func floor_cost(floor_id: String) -> int:
	return int(DataRegistry.get_def("floors", floor_id).get("cost", 0))


## What taking something down gives back.
static func refund(cost: int) -> int:
	return cost * int(config().get("refund_percent", 50)) / 100


# --- resources (data/resources.json) ----------------------------------------------------

static func resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for def in DataRegistry.get_list("resources"):
		ids.append(str(def["id"]))
	return ids


static func resource_name(resource_id: String) -> String:
	return str(DataRegistry.get_def("resources", resource_id).get("name", resource_id.capitalize()))


## What the shop sells it for, and what building costs when you are short of it.
static func resource_price(resource_id: String) -> int:
	return int(DataRegistry.get_def("resources", resource_id).get("price", 1))


## What the shop pays for `quantity` of it: less than it sells for, and more on a market day
## (`multiplier`).
static func sell_price(resource_id: String, quantity: int, multiplier: float = 1.0) -> int:
	return roundi(float(resource_price(resource_id) * quantity) * float(config().get("sell_percent", 70)) / 100.0 * multiplier)


## The materials an object takes ("materials" in objects.json), by resource id.
static func materials(object_def_id: String) -> Dictionary:
	return DataRegistry.get_def("objects", object_def_id).get("materials", {})


## What putting up an object costs when `stock` is what you hold: materials you have stand in for
## their price in coin, so what you lack is bought at the shop's price. Returns { "coins": int,
## "uses": { resource id: quantity taken from the stock } }.
static func build_price(object_def_id: String, stock: Dictionary) -> Dictionary:
	var uses := {}
	var saved := 0
	var needed := materials(object_def_id)
	for resource_id in needed:
		var take := mini(int(stock.get(resource_id, 0)), int(needed[resource_id]))
		if take > 0:
			uses[resource_id] = take
			saved += take * resource_price(str(resource_id))
	return { "coins": maxi(0, object_cost(object_def_id) - saved), "uses": uses }


## "2d, or 1 wood" for the tooltip of something in the build menu.
static func cost_text(object_def_id: String) -> String:
	var cost := object_cost(object_def_id)
	if cost <= 0:
		return ""
	var needed := materials(object_def_id)
	if needed.is_empty():
		return format(cost)
	var parts: Array[String] = []
	for resource_id in needed:
		parts.append("%d %s" % [int(needed[resource_id]), resource_name(str(resource_id)).to_lower()])
	return "%s, or %s and the rest in coin" % [format(cost), " and ".join(parts)]


## "3 wood, 1 stone", or "" for nothing.
static func stock_text(stock: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in resource_ids():
		if int(stock.get(resource_id, 0)) > 0:
			parts.append("%d %s" % [int(stock[resource_id]), resource_name(resource_id).to_lower()])
	return ", ".join(parts)


## The name of a resource or a tool.
static func item_name(item_id: String) -> String:
	if Skills.is_tool_id(item_id):
		return Skills.tool_name(item_id)
	return resource_name(item_id)


## Like stock_text, but resources and tools both: "2 wood, 1 axe".
static func goods_text(goods: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in resource_ids():
		if int(goods.get(resource_id, 0)) > 0:
			parts.append("%d %s" % [int(goods[resource_id]), resource_name(resource_id).to_lower()])
	for tool_id in Skills.tool_ids():
		if int(goods.get(tool_id, 0)) > 0:
			parts.append("%d %s" % [int(goods[tool_id]), Skills.tool_name(tool_id).to_lower()])
	return ", ".join(parts)
