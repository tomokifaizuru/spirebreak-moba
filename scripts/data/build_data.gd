class_name BuildData
extends Resource
## The recommended item build for one hero (data/builds/*.tres). Edit the order in the Inspector;
## the first 3-5 entries are what the recommendation popup walks through.

@export var hero: HeroData
## Buy order. The popup recommends the first one the player doesn't own yet.
@export var items: Array[ItemData] = []
