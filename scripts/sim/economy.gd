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
