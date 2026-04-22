# H3 Geo Tool

A command-line tool to generate [H3](https://h3geo.org) cell IDs from GPS coordinates.

H3 is a hierarchical hexagonal geospatial indexing system developed by Uber for efficiently indexing and querying geographic data.

## Installation

```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install the h3 Python package
pip install -r requirements.txt
```

To activate the environment in future sessions:
```bash
source venv/bin/activate
```

## Usage

### Convert GPS coordinates to H3 cell ID

```bash
# Default resolution 9 (~105m hexagon edge)
python h3_tool.py --lat 37.7749 --lng -122.4194

# Specify resolution (0-15)
python h3_tool.py --lat 37.7749 --lng -122.4194 --resolution 12

# Show all resolutions at once
python h3_tool.py --lat 37.7749 --lng -122.4194 --all-resolutions
```

### Get detailed cell information

```bash
# From coordinates
python h3_tool.py --lat 37.7749 --lng -122.4194 --info

# From existing H3 cell ID
python h3_tool.py --cell 89283082837ffff --info
```

### Get neighboring cells

```bash
# Direct neighbors (1 ring)
python h3_tool.py --lat 37.7749 --lng -122.4194 --neighbors

# Multiple rings
python h3_tool.py --lat 37.7749 --lng -122.4194 --neighbors --rings 2
```

## Visualize H3 Cell on Map

You can view the exact hexagon location on a map by using the H3 website:

```
https://h3geo.org/#hex={cell_id}
```

**Examples:**
- Hollywood (Res 4): https://h3geo.org/#hex=8429a1dffffffff
- Anaheim (Res 4): https://h3geo.org/#hex=8429a0bffffffff
- San Francisco (Res 9): https://h3geo.org/#hex=89283082803ffff

Simply replace `{cell_id}` with your H3 cell ID to see the hexagon boundary on the map.

## Resolution Reference

| Resolution | Avg Hexagon Area | Avg Edge Length | Use Case |
|------------|------------------|-----------------|----------|
| 0 | ~4,250,547 km² | ~1,107 km | Continent |
| 5 | ~252.9 km² | ~8.5 km | State/Province |
| 9 | ~0.1 km² | ~174 m | Neighborhood |
| 10 | ~0.015 km² | ~66 m | Block |
| 12 | ~0.0003 km² | ~9 m | Building |
| 15 | ~0.0000009 km² | ~0.5 m | Sub-meter |

## Python API

```python
from h3_tool import gps_to_h3, get_cell_info, get_neighbors

# Convert GPS to H3
cell_id = gps_to_h3(37.7749, -122.4194, resolution=9)
print(cell_id)  # '89283082837ffff'

# Get cell info
info = get_cell_info(cell_id)
print(info['area_km2'])  # ~0.1 km²

# Get neighbors
neighbors = get_neighbors(cell_id, k=1)
print(len(neighbors))  # 7 (center + 6 neighbors)
```

## Reverse Geocoding API

You can use the [LocationIQ](https://locationiq.com) API to convert GPS coordinates to address information.

### API Endpoint

```
https://us1.locationiq.com/v1/reverse?key=<API_KEY>&lat=<LATITUDE>&lon=<LONGITUDE>&format=json
```

### Example

**Request:**
```bash
curl "https://us1.locationiq.com/v1/reverse?key=pk.059fd15e362a73f7f0a8392b43a27d87&lat=36.099857&lon=-115.26179&format=json"
```

**Response:**
```json
{
  "place_id": "331443034397",
  "lat": "36.099911",
  "lon": "-115.261943",
  "display_name": "7825, Geyser Hill Lane, Spanish Trails, Spring Valley, Clark County, Nevada, 89147, USA",
  "address": {
    "house_number": "7825",
    "road": "Geyser Hill Lane",
    "neighbourhood": "Spanish Trails",
    "city": "Spring Valley",
    "county": "Clark County",
    "state": "Nevada",
    "postcode": "89147",
    "country": "United States of America",
    "country_code": "us"
  }
}
```

### Response Fields

| Field | Description |
|-------|-------------|
| `lat`, `lon` | Corrected coordinates |
| `display_name` | Full formatted address |
| `address.city` | City name |
| `address.county` | County name |
| `address.state` | State/Province |
| `address.postcode` | ZIP/Postal code |
| `address.country` | Country name |

## Resources

- [H3 Documentation](https://h3geo.org)
- [H3 API Reference](https://h3geo.org/docs/api/indexing)
- [H3 GitHub](https://github.com/uber/h3)
- [Resolution Table](https://h3geo.org/docs/core-library/restable)
- [LocationIQ API](https://locationiq.com/docs)
