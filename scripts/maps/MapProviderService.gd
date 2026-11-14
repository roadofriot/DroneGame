class_name MapProviderService
extends RefCounted

## MapProviderService: Multi-provider geographical location search,
## offline landmark geocache, Web Mercator projection, and mandatory data attribution.

const ATTRIBUTION_TEXT = "Map data © OpenStreetMap contributors, ODbL 1.0. Offline Cartographic Engine by MindSparQ."
const TERMS_URL = "https://www.openstreetmap.org/copyright"

# Built-in offline geocache supporting zero-network operation
const OFFLINE_LOCATIONS = [
	{
		"id": "loc_butwal",
		"name": "Butwal",
		"display_name": "Butwal, Rupandehi, Lumbini Province, Nepal",
		"region": "Rupandehi",
		"country": "Nepal",
		"lat": 27.7006,
		"lon": 83.4484,
		"elevation_m": 150.0,
		"has_authored_game_world": true,
		"game_world_id": "butwal_city",
		"description": "Historic trade crossroads and commercial hub situated at the base of the Chure hills."
	},
	{
		"id": "loc_tilottama",
		"name": "Tilottama",
		"display_name": "Tilottama Municipality, Rupandehi, Nepal",
		"region": "Rupandehi",
		"country": "Nepal",
		"lat": 27.6360,
		"lon": 83.4730,
		"elevation_m": 130.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "Expanding residential and agricultural valley bordering Butwal and Bhairahawa."
	},
	{
		"id": "loc_lumbini",
		"name": "Lumbini Sacred Garden",
		"display_name": "Lumbini Sanskritik, Rupandehi, Nepal",
		"region": "Rupandehi",
		"country": "Nepal",
		"lat": 27.4840,
		"lon": 83.2760,
		"elevation_m": 110.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "UNESCO World Heritage cultural sanctuary and birthplace of Gautama Buddha."
	},
	{
		"id": "loc_pokhara",
		"name": "Pokhara Phewa Lake",
		"display_name": "Pokhara, Kaski District, Gandaki Province, Nepal",
		"region": "Kaski",
		"country": "Nepal",
		"lat": 28.2096,
		"lon": 83.9856,
		"elevation_m": 822.0,
		"has_authored_game_world": true,
		"game_world_id": "mountain_lake",
		"description": "Scenic alpine lake basin under the Annapurna mountain range."
	},
	{
		"id": "loc_kathmandu",
		"name": "Kathmandu Durbar Valley",
		"display_name": "Kathmandu, Bagmati Province, Nepal",
		"region": "Kathmandu",
		"country": "Nepal",
		"lat": 27.7172,
		"lon": 85.3240,
		"elevation_m": 1400.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "Ancient high-altitude Himalayan capital basin rich in cultural monuments."
	},
	{
		"id": "loc_everest",
		"name": "Mount Everest (Sagarmatha)",
		"display_name": "Mount Everest, Solukhumbu, Nepal",
		"region": "Solukhumbu",
		"country": "Nepal",
		"lat": 27.9881,
		"lon": 86.9250,
		"elevation_m": 8848.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "The highest summit on Earth, towering in the Mahalangur Himal sub-range."
	},
	{
		"id": "loc_tokyo",
		"name": "Tokyo Shibuya",
		"display_name": "Shibuya, Tokyo Metropolis, Japan",
		"region": "Kanto",
		"country": "Japan",
		"lat": 35.6595,
		"lon": 139.7004,
		"elevation_m": 38.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "High-density futuristic metropolis and major transport node."
	},
	{
		"id": "loc_san_francisco",
		"name": "San Francisco Bay",
		"display_name": "San Francisco, California, United States",
		"region": "California",
		"country": "United States",
		"lat": 37.7749,
		"lon": -122.4194,
		"elevation_m": 16.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "Coastal peninsula surrounded by the Pacific Ocean and San Francisco Bay."
	},
	{
		"id": "loc_london",
		"name": "London Greenwich",
		"display_name": "London, Greater London, United Kingdom",
		"region": "Greater London",
		"country": "United Kingdom",
		"lat": 51.5074,
		"lon": -0.1278,
		"elevation_m": 11.0,
		"has_authored_game_world": false,
		"game_world_id": "",
		"description": "Historic maritime capital and origin of the Prime Meridian."
	}
]

static func get_attribution() -> String:
	return ATTRIBUTION_TEXT

static func get_terms_url() -> String:
	return TERMS_URL

static func get_default_location() -> Dictionary:
	return OFFLINE_LOCATIONS[0]

static func search_locations(query: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var clean_query = query.strip_edges().to_lower()

	if clean_query.is_empty():
		for loc in OFFLINE_LOCATIONS:
			results.append(loc.duplicate(true))
		return results

	# Check for direct coordinate input (e.g. "27.7006, 83.4484")
	if "," in clean_query:
		var parts = clean_query.split(",")
		if parts.size() == 2:
			var lat_val = parts[0].strip_edges().to_float()
			var lon_val = parts[1].strip_edges().to_float()
			if absf(lat_val) <= 90.0 and absf(lon_val) <= 180.0:
				results.append({
					"id": "loc_custom_coords",
					"name": "Custom Coordinates",
					"display_name": "Coordinate Point (%.4f°, %.4f°)" % [lat_val, lon_val],
					"region": "Custom",
					"country": "Global",
					"lat": lat_val,
					"lon": lon_val,
					"elevation_m": 100.0,
					"has_authored_game_world": false,
					"game_world_id": "",
					"description": "User-specified GPS coordinate destination."
				})

	# Substring search across offline catalogue
	for loc in OFFLINE_LOCATIONS:
		var n = loc.get("name", "").to_lower()
		var d = loc.get("display_name", "").to_lower()
		var r = loc.get("region", "").to_lower()
		var c = loc.get("country", "").to_lower()

		if clean_query in n or clean_query in d or clean_query in r or clean_query in c:
			# Prevent duplicate if coordinate search matched
			var already = false
			for res in results:
				if res.get("id") == loc.get("id"):
					already = true
					break
			if not already:
				results.append(loc.duplicate(true))

	return results

static func lat_lon_to_mercator(lat_deg: float, lon_deg: float) -> Vector2:
	var x = (lon_deg + 180.0) / 360.0
	var lat_rad = deg_to_rad(clampf(lat_deg, -85.0511, 85.0511))
	var y = (1.0 - (log(tan(lat_rad) + (1.0 / cos(lat_rad))) / PI)) / 2.0
	return Vector2(clampf(x, 0.0, 1.0), clampf(y, 0.0, 1.0))

static func mercator_to_lat_lon(merc_pos: Vector2) -> Vector2:
	var lon = (merc_pos.x * 360.0) - 180.0
	var n = PI - (2.0 * PI * merc_pos.y)
	var lat = rad_to_deg(atan(sinh(n)))
	return Vector2(lat, lon)
