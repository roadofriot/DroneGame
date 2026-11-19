class_name NepalWorldRegions
extends RefCounted

## NepalWorldRegions: Single source of truth for the 8 Nepal Adventure Destinations.
## Defines true world coordinates, biomes, landmarks, checkpoints, and coin trails
## for continuous 20+ km city-to-city open-world exploration.

const STAGES: Array[Dictionary] = [
	{
		"id": "stage_01_butwal",
		"stage_number": 1,
		"name": "Butwal City",
		"region": "Rupandehi Valley, Nepal",
		"description": "Vibrant sub-Himalayan urban commercial hub with roads and parks.",
		"difficulty": "Beginner",
		"unlocked_by_default": true,
		"required_previous_stage": "",
		"target_coordinates": Vector3(0.0, 12.0, 0.0),
		"arrival_radius": 45.0,
		"biome": "urban_city",
		"terrain_color": Color(0.35, 0.38, 0.36),
		"fog_color": Color(0.72, 0.78, 0.85),
		"landmarks": [
			{
				"id": "tinau_bridge",
				"name": "Tinau River Suspension Bridge",
				"location": "Butwal, Nepal",
				"position": Vector3(-120.0, 8.0, 150.0),
				"discovery_radius": 35.0,
				"xp_reward": 100,
				"coin_reward": 150
			},
			{
				"id": "manimukunda_park",
				"name": "Manimukunda Historic Park",
				"location": "Butwal, Nepal",
				"position": Vector3(220.0, 14.0, -180.0),
				"discovery_radius": 35.0,
				"xp_reward": 120,
				"coin_reward": 180
			},
			{
				"id": "golpark_tower",
				"name": "Golpark Commercial Tower",
				"location": "Butwal, Nepal",
				"position": Vector3(0.0, 25.0, -260.0),
				"discovery_radius": 30.0,
				"xp_reward": 150,
				"coin_reward": 200
			}
		],
		"checkpoints": [
			Vector3(100.0, 16.0, 600.0),
			Vector3(250.0, 14.0, 1400.0),
			Vector3(380.0, 12.0, 2200.0)
		],
		"landing_pad_position": Vector3(0.0, 12.1, 0.0)
	},
	{
		"id": "stage_02_lumbini",
		"stage_number": 2,
		"name": "Lumbini Gardens",
		"region": "Kapilvastu Plains, Nepal",
		"description": "Sacred peaceful monasteries, bodhi groves, and cultural ponds.",
		"difficulty": "Easy",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_01_butwal",
		"target_coordinates": Vector3(500.0, 6.0, 3000.0),
		"arrival_radius": 50.0,
		"biome": "sacred_gardens",
		"terrain_color": Color(0.24, 0.45, 0.22),
		"fog_color": Color(0.85, 0.88, 0.82),
		"landmarks": [
			{
				"id": "mayadevi_temple",
				"name": "Mayadevi Temple & Sacred Pond",
				"location": "Lumbini, Nepal",
				"position": Vector3(500.0, 6.0, 3000.0),
				"discovery_radius": 40.0,
				"xp_reward": 180,
				"coin_reward": 250
			},
			{
				"id": "peace_pagoda",
				"name": "World Peace Pagoda",
				"location": "Lumbini, Nepal",
				"position": Vector3(350.0, 22.0, 3200.0),
				"discovery_radius": 35.0,
				"xp_reward": 150,
				"coin_reward": 200
			},
			{
				"id": "ashoka_pillar",
				"name": "Ancient Ashoka Pillar",
				"location": "Lumbini, Nepal",
				"position": Vector3(580.0, 9.0, 2850.0),
				"discovery_radius": 30.0,
				"xp_reward": 140,
				"coin_reward": 180
			}
		],
		"checkpoints": [
			Vector3(700.0, 18.0, 2400.0),
			Vector3(1100.0, 45.0, 1000.0),
			Vector3(1600.0, 90.0, -500.0)
		],
		"landing_pad_position": Vector3(500.0, 6.1, 3000.0)
	},
	{
		"id": "stage_03_tansen",
		"stage_number": 3,
		"name": "Palpa - Tansen",
		"region": "Mid-Western Hills, Nepal",
		"description": "Historic hill station with traditional Newari buildings and viewpoints.",
		"difficulty": "Intermediate",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_02_lumbini",
		"target_coordinates": Vector3(2200.0, 130.0, -2000.0),
		"arrival_radius": 50.0,
		"biome": "mountain_hills",
		"terrain_color": Color(0.38, 0.42, 0.28),
		"fog_color": Color(0.70, 0.78, 0.88),
		"landmarks": [
			{
				"id": "shreenagar_tower",
				"name": "Shreenagar Hill Viewpoint Tower",
				"location": "Tansen, Palpa, Nepal",
				"position": Vector3(2200.0, 165.0, -2000.0),
				"discovery_radius": 35.0,
				"xp_reward": 200,
				"coin_reward": 300
			},
			{
				"id": "tansen_durbar",
				"name": "Tansen Durbar Historic Palace",
				"location": "Tansen, Palpa, Nepal",
				"position": Vector3(2050.0, 132.0, -1850.0),
				"discovery_radius": 35.0,
				"xp_reward": 180,
				"coin_reward": 240
			},
			{
				"id": "ranighat_canyon",
				"name": "Ranighat Gorge Vista",
				"location": "Palpa, Nepal",
				"position": Vector3(2450.0, 110.0, -2300.0),
				"discovery_radius": 40.0,
				"xp_reward": 190,
				"coin_reward": 260
			}
		],
		"checkpoints": [
			Vector3(1500.0, 105.0, -3200.0),
			Vector3(500.0, 80.0, -4500.0),
			Vector3(-800.0, 95.0, -5800.0)
		],
		"landing_pad_position": Vector3(2200.0, 130.1, -2000.0)
	},
	{
		"id": "stage_04_pokhara",
		"stage_number": 4,
		"name": "Pokhara Lakeside",
		"region": "Annapurna Gateway, Nepal",
		"description": "Serene waterfront at Phewa Lake overlooking the high Himalayas.",
		"difficulty": "Intermediate",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_03_tansen",
		"target_coordinates": Vector3(-2000.0, 45.0, -7000.0),
		"arrival_radius": 55.0,
		"biome": "lake_valley",
		"terrain_color": Color(0.22, 0.40, 0.35),
		"fog_color": Color(0.65, 0.80, 0.95),
		"landmarks": [
			{
				"id": "phewa_lake",
				"name": "Phewa Lake Waterfront",
				"location": "Pokhara, Nepal",
				"position": Vector3(-2000.0, 45.0, -7000.0),
				"discovery_radius": 50.0,
				"xp_reward": 220,
				"coin_reward": 320
			},
			{
				"id": "tal_barahi",
				"name": "Tal Barahi Island Temple",
				"location": "Phewa Lake, Pokhara, Nepal",
				"position": Vector3(-1850.0, 46.0, -6850.0),
				"discovery_radius": 35.0,
				"xp_reward": 240,
				"coin_reward": 350
			},
			{
				"id": "pumdikot_stupa",
				"name": "Pumdikot Panoramic Ridge",
				"location": "Pokhara, Nepal",
				"position": Vector3(-2300.0, 98.0, -7250.0),
				"discovery_radius": 40.0,
				"xp_reward": 200,
				"coin_reward": 280
			}
		],
		"checkpoints": [
			Vector3(-500.0, 50.0, -6000.0),
			Vector3(1200.0, 35.0, -4000.0),
			Vector3(2800.0, 22.0, -1800.0)
		],
		"landing_pad_position": Vector3(-2000.0, 45.1, -7000.0)
	},
	{
		"id": "stage_05_chitwan",
		"stage_number": 5,
		"name": "Chitwan Wildlife",
		"region": "Terai Lowlands, Nepal",
		"description": "Dense tropical Sal forests, Rapti River, and tall elephant grasslands.",
		"difficulty": "Advanced",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_04_pokhara",
		"target_coordinates": Vector3(4200.0, 18.0, 500.0),
		"arrival_radius": 50.0,
		"biome": "subtropical_forest",
		"terrain_color": Color(0.26, 0.48, 0.20),
		"fog_color": Color(0.78, 0.82, 0.70),
		"landmarks": [
			{
				"id": "rapti_watchtower",
				"name": "Rapti Riverbank Watchtower",
				"location": "Chitwan National Park, Nepal",
				"position": Vector3(4200.0, 24.0, 500.0),
				"discovery_radius": 35.0,
				"xp_reward": 250,
				"coin_reward": 380
			},
			{
				"id": "sauraha_safari",
				"name": "Sauraha Jungle Safari Outpost",
				"location": "Chitwan, Nepal",
				"position": Vector3(4400.0, 19.0, 350.0),
				"discovery_radius": 35.0,
				"xp_reward": 220,
				"coin_reward": 300
			},
			{
				"id": "elephant_grasslands",
				"name": "Elephant Grass Sanctuary",
				"location": "Chitwan, Nepal",
				"position": Vector3(3950.0, 17.0, 700.0),
				"discovery_radius": 40.0,
				"xp_reward": 210,
				"coin_reward": 290
			}
		],
		"checkpoints": [
			Vector3(5200.0, 42.0, 0.0),
			Vector3(6400.0, 75.0, -800.0),
			Vector3(7600.0, 125.0, -1600.0)
		],
		"landing_pad_position": Vector3(4200.0, 18.1, 500.0)
	},
	{
		"id": "stage_06_kathmandu",
		"stage_number": 6,
		"name": "Kathmandu Valley",
		"region": "Central Valley, Nepal",
		"description": "Dense heritage city of pagoda temples, shrines, and historic squares.",
		"difficulty": "Advanced",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_05_chitwan",
		"target_coordinates": Vector3(9000.0, 140.0, -2500.0),
		"arrival_radius": 55.0,
		"biome": "ancient_urban",
		"terrain_color": Color(0.42, 0.35, 0.28),
		"fog_color": Color(0.80, 0.75, 0.70),
		"landmarks": [
			{
				"id": "swayambhu_spire",
				"name": "Swayambhunath Golden Stupa",
				"location": "Kathmandu, Nepal",
				"position": Vector3(8850.0, 175.0, -2650.0),
				"discovery_radius": 45.0,
				"xp_reward": 280,
				"coin_reward": 400
			},
			{
				"id": "boudha_dome",
				"name": "Boudhanath Great Mandala Stupa",
				"location": "Kathmandu, Nepal",
				"position": Vector3(9200.0, 145.0, -2350.0),
				"discovery_radius": 45.0,
				"xp_reward": 290,
				"coin_reward": 420
			},
			{
				"id": "durbar_square",
				"name": "Kathmandu Durbar Square Pad",
				"location": "Kathmandu, Nepal",
				"position": Vector3(9000.0, 140.0, -2500.0),
				"discovery_radius": 35.0,
				"xp_reward": 260,
				"coin_reward": 360
			}
		],
		"checkpoints": [
			Vector3(10000.0, 160.0, -3500.0),
			Vector3(11000.0, 210.0, -4800.0),
			Vector3(11800.0, 280.0, -6200.0)
		],
		"landing_pad_position": Vector3(9000.0, 140.1, -2500.0)
	},
	{
		"id": "stage_07_mountain_adventure",
		"stage_number": 7,
		"name": "Mountain Adventure",
		"region": "High Himalayas, Nepal",
		"description": "Snow-covered peaks, sheer rock valleys, and roaring crosswinds.",
		"difficulty": "Expert",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_06_kathmandu",
		"target_coordinates": Vector3(12800.0, 340.0, -7500.0),
		"arrival_radius": 60.0,
		"biome": "alpine_glacier",
		"terrain_color": Color(0.60, 0.65, 0.72),
		"fog_color": Color(0.75, 0.82, 0.90),
		"landmarks": [
			{
				"id": "canyon_bridge",
				"name": "High Canyon Suspension Bridge",
				"location": "Solukhumbu, Nepal",
				"position": Vector3(12650.0, 348.0, -7400.0),
				"discovery_radius": 40.0,
				"xp_reward": 320,
				"coin_reward": 450
			},
			{
				"id": "glacial_ledge",
				"name": "Glacial Moraine Ledge",
				"location": "Solukhumbu, Nepal",
				"position": Vector3(12800.0, 340.0, -7500.0),
				"discovery_radius": 45.0,
				"xp_reward": 300,
				"coin_reward": 400
			},
			{
				"id": "alpine_refuge",
				"name": "High Altitude Alpine Refuge",
				"location": "Solukhumbu, Nepal",
				"position": Vector3(13050.0, 365.0, -7680.0),
				"discovery_radius": 35.0,
				"xp_reward": 310,
				"coin_reward": 430
			}
		],
		"checkpoints": [
			Vector3(13800.0, 390.0, -8800.0),
			Vector3(14600.0, 450.0, -9800.0),
			Vector3(15400.0, 520.0, -11000.0)
		],
		"landing_pad_position": Vector3(12800.0, 340.1, -7500.0)
	},
	{
		"id": "stage_08_everest_expedition",
		"stage_number": 8,
		"name": "Everest Expedition",
		"region": "Mount Everest (Sagarmatha), Nepal",
		"description": "High-altitude mountaineering base camp at the rooftop of the world.",
		"difficulty": "Master",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_07_mountain_adventure",
		"target_coordinates": Vector3(16500.0, 620.0, -12500.0),
		"arrival_radius": 65.0,
		"biome": "everest_summit",
		"terrain_color": Color(0.92, 0.94, 0.98),
		"fog_color": Color(0.85, 0.90, 0.98),
		"landmarks": [
			{
				"id": "everest_base_camp",
				"name": "Khumbu Everest Base Camp Tents",
				"location": "Sagarmatha, Nepal",
				"position": Vector3(16500.0, 620.0, -12500.0),
				"discovery_radius": 50.0,
				"xp_reward": 500,
				"coin_reward": 1000
			},
			{
				"id": "khumbu_icefall",
				"name": "Khumbu Icefall Serac Tower",
				"location": "Sagarmatha, Nepal",
				"position": Vector3(16300.0, 670.0, -12800.0),
				"discovery_radius": 45.0,
				"xp_reward": 450,
				"coin_reward": 800
			},
			{
				"id": "sagarmatha_peak",
				"name": "Sagarmatha Summit Crown Vista",
				"location": "Mount Everest, Nepal",
				"position": Vector3(16800.0, 850.0, -13200.0),
				"discovery_radius": 60.0,
				"xp_reward": 600,
				"coin_reward": 1200
			}
		],
		"checkpoints": [
			Vector3(15800.0, 560.0, -11600.0),
			Vector3(16150.0, 590.0, -12050.0),
			Vector3(16400.0, 615.0, -12350.0)
		],
		"landing_pad_position": Vector3(16500.0, 620.1, -12500.0)
	},
	{
		"id": "stage_09_annapurna_sanctuary",
		"stage_number": 9,
		"name": "Annapurna Sanctuary",
		"region": "Annapurna Massif, Nepal",
		"description": "High glacial amphitheater ringed by Machapuchare and Annapurna peaks.",
		"difficulty": "Master",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_08_everest_expedition",
		"target_coordinates": Vector3(-4500.0, 480.0, -11000.0),
		"arrival_radius": 60.0,
		"biome": "alpine_basin",
		"terrain_color": Color(0.72, 0.78, 0.86),
		"fog_color": Color(0.80, 0.88, 0.95),
		"landmarks": [
			{
				"id": "machapuchare_ridge",
				"name": "Machapuchare Fishtail Ridge",
				"location": "Annapurna Range, Nepal",
				"position": Vector3(-4300.0, 510.0, -10800.0),
				"discovery_radius": 45.0,
				"xp_reward": 550,
				"coin_reward": 1100
			},
			{
				"id": "annapurna_base_camp",
				"name": "Annapurna Base Camp Sanctuary",
				"location": "Annapurna Range, Nepal",
				"position": Vector3(-4500.0, 480.0, -11000.0),
				"discovery_radius": 50.0,
				"xp_reward": 500,
				"coin_reward": 950
			}
		],
		"checkpoints": [
			Vector3(-2800.0, 180.0, -8200.0),
			Vector3(-3400.0, 310.0, -9200.0),
			Vector3(-4100.0, 420.0, -10200.0)
		],
		"landing_pad_position": Vector3(-4500.0, 480.1, -11000.0)
	},
	{
		"id": "stage_10_mustang_kingdom",
		"stage_number": 10,
		"name": "Mustang - Lo Manthang",
		"region": "Upper Mustang Desert, Nepal",
		"description": "Ancient walled capital, arid red clay cliffs, and sacred sky caves.",
		"difficulty": "Grand Master",
		"unlocked_by_default": false,
		"required_previous_stage": "stage_09_annapurna_sanctuary",
		"target_coordinates": Vector3(-1500.0, 390.0, -16000.0),
		"arrival_radius": 65.0,
		"biome": "canyon_desert",
		"terrain_color": Color(0.78, 0.52, 0.38),
		"fog_color": Color(0.88, 0.80, 0.70),
		"landmarks": [
			{
				"id": "lo_manthang_fortress",
				"name": "Ancient Lo Manthang Walled Fortress",
				"location": "Upper Mustang, Nepal",
				"position": Vector3(-1500.0, 390.0, -16000.0),
				"discovery_radius": 55.0,
				"xp_reward": 700,
				"coin_reward": 1500
			},
			{
				"id": "mustang_sky_caves",
				"name": "Mustang Cliffside Sky Caves",
				"location": "Upper Mustang, Nepal",
				"position": Vector3(-1350.0, 420.0, -15700.0),
				"discovery_radius": 45.0,
				"xp_reward": 600,
				"coin_reward": 1200
			}
		],
		"checkpoints": [
			Vector3(-3200.0, 440.0, -12500.0),
			Vector3(-2400.0, 410.0, -14200.0),
			Vector3(-1800.0, 395.0, -15300.0)
		],
		"landing_pad_position": Vector3(-1500.0, 390.1, -16000.0)
	}
]

static func get_all_stages() -> Array[Dictionary]:
	return STAGES

static func get_stage_by_id(stage_id: String) -> Dictionary:
	for st in STAGES:
		if st.get("id") == stage_id:
			return st
	return {}

static func get_stage_by_number(num: int) -> Dictionary:
	for st in STAGES:
		if st.get("stage_number") == num:
			return st
	return {}

static func get_next_stage(stage_id: String) -> Dictionary:
	var cur = get_stage_by_id(stage_id)
	if cur.is_empty():
		return {}
	var next_num = cur.get("stage_number", 1) + 1
	return get_stage_by_number(next_num)

## Determines the active geographic region/biome based on 64-bit true coordinates.
static func get_region_at_coordinates(coords: Vector3) -> Dictionary:
	var closest_stage: Dictionary = STAGES[0]
	var min_dist_sq = INF
	for st in STAGES:
		var target: Vector3 = st.get("target_coordinates", Vector3.ZERO)
		var d_sq = coords.distance_squared_to(target)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			closest_stage = st
	return closest_stage
