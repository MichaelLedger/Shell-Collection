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

## Resources

- [H3 Documentation](https://h3geo.org)
- [H3 API Reference](https://h3geo.org/docs/api/indexing)
- [H3 GitHub](https://github.com/uber/h3)
- [Resolution Table](https://h3geo.org/docs/core-library/restable)
