#!/usr/bin/env python3
"""
H3 Geo Tool - Generate H3 cell IDs from GPS coordinates

H3 is a hierarchical hexagonal geospatial indexing system developed by Uber.
Learn more at: https://h3geo.org
"""

import h3
import argparse
import sys


def gps_to_h3(lat: float, lng: float, resolution: int = 9) -> str:
    """
    Convert GPS coordinates to H3 cell ID.
    
    Args:
        lat: Latitude (-90 to 90)
        lng: Longitude (-180 to 180)
        resolution: H3 resolution (0-15), default 9
                   - 0: ~4,250,547 km² (continent scale)
                   - 5: ~252.9 km² (state/province scale)
                   - 9: ~0.1 km² (neighborhood scale, ~105m edge)
                   - 12: ~0.0003 km² (building scale, ~9m edge)
                   - 15: ~0.0000009 km² (sub-meter scale)
    
    Returns:
        H3 cell ID as hexadecimal string
    """
    if not -90 <= lat <= 90:
        raise ValueError(f"Latitude must be between -90 and 90, got {lat}")
    if not -180 <= lng <= 180:
        raise ValueError(f"Longitude must be between -180 and 180, got {lng}")
    if not 0 <= resolution <= 15:
        raise ValueError(f"Resolution must be between 0 and 15, got {resolution}")
    
    return h3.latlng_to_cell(lat, lng, resolution)


def get_cell_info(cell_id: str) -> dict:
    """
    Get information about an H3 cell.
    
    Args:
        cell_id: H3 cell ID (hexadecimal string)
    
    Returns:
        Dictionary with cell information
    """
    if not h3.is_valid_cell(cell_id):
        raise ValueError(f"Invalid H3 cell ID: {cell_id}")
    
    lat, lng = h3.cell_to_latlng(cell_id)
    boundary = h3.cell_to_boundary(cell_id)
    
    return {
        "cell_id": cell_id,
        "resolution": h3.get_resolution(cell_id),
        "center_lat": lat,
        "center_lng": lng,
        "boundary": boundary,
        "area_km2": h3.cell_area(cell_id, unit="km^2"),
        "parent": h3.cell_to_parent(cell_id) if h3.get_resolution(cell_id) > 0 else None,
        "is_pentagon": h3.is_pentagon(cell_id),
    }


def get_neighbors(cell_id: str, k: int = 1) -> list:
    """
    Get neighboring cells within k distance.
    
    Args:
        cell_id: H3 cell ID
        k: Number of rings (default 1)
    
    Returns:
        List of neighboring cell IDs
    """
    if not h3.is_valid_cell(cell_id):
        raise ValueError(f"Invalid H3 cell ID: {cell_id}")
    
    return list(h3.grid_disk(cell_id, k))


def main():
    parser = argparse.ArgumentParser(
        description="H3 Geo Tool - Convert GPS coordinates to H3 cell IDs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert GPS to H3 cell ID (default resolution 9)
  python h3_tool.py --lat 37.7749 --lng -122.4194

  # Specify resolution (0-15)
  python h3_tool.py --lat 37.7749 --lng -122.4194 --resolution 12

  # Get cell info from existing H3 ID
  python h3_tool.py --cell 89283082837ffff --info

  # Get neighbors of a cell
  python h3_tool.py --cell 89283082837ffff --neighbors

Resolution Reference:
  0:  ~4,250,547 km²  (continent)
  5:  ~252.9 km²      (state/province)
  9:  ~0.1 km²        (neighborhood, ~105m edge)
  12: ~0.0003 km²     (building, ~9m edge)
  15: ~0.0000009 km²  (sub-meter)

More info: https://h3geo.org
        """
    )
    
    parser.add_argument("--lat", type=float, help="Latitude (-90 to 90)")
    parser.add_argument("--lng", type=float, help="Longitude (-180 to 180)")
    parser.add_argument("--resolution", "-r", type=int, default=9,
                        help="H3 resolution 0-15 (default: 9)")
    parser.add_argument("--cell", type=str, help="H3 cell ID for info/neighbors lookup")
    parser.add_argument("--info", action="store_true", help="Show detailed cell info")
    parser.add_argument("--neighbors", "-n", action="store_true", help="Show neighboring cells")
    parser.add_argument("--rings", "-k", type=int, default=1,
                        help="Number of rings for neighbors (default: 1)")
    parser.add_argument("--all-resolutions", "-a", action="store_true",
                        help="Show H3 IDs for all resolutions (0-15)")
    
    args = parser.parse_args()
    
    # Convert GPS to H3
    if args.lat is not None and args.lng is not None:
        try:
            if args.all_resolutions:
                print(f"GPS: ({args.lat}, {args.lng})")
                print("-" * 50)
                for res in range(16):
                    cell_id = gps_to_h3(args.lat, args.lng, res)
                    area = h3.cell_area(cell_id, unit="km^2")
                    print(f"Resolution {res:2d}: {cell_id}  (area: {area:.6f} km²)")
            else:
                cell_id = gps_to_h3(args.lat, args.lng, args.resolution)
                print(f"H3 Cell ID: {cell_id}")
                
                if args.info:
                    info = get_cell_info(cell_id)
                    print(f"Resolution:  {info['resolution']}")
                    print(f"Center:      ({info['center_lat']:.6f}, {info['center_lng']:.6f})")
                    print(f"Area:        {info['area_km2']:.6f} km²")
                    print(f"Is Pentagon: {info['is_pentagon']}")
                    if info['parent']:
                        print(f"Parent:      {info['parent']}")
                    print(f"Map URL:     https://h3geo.org/#hex={cell_id}")
                
                if args.neighbors:
                    neighbors = get_neighbors(cell_id, args.rings)
                    print(f"\nNeighbors (k={args.rings}): {len(neighbors)} cells")
                    for n in neighbors:
                        print(f"  {n}")
                        
        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Get info for existing cell
    elif args.cell:
        try:
            if args.info or (not args.neighbors):
                info = get_cell_info(args.cell)
                print(f"Cell ID:     {info['cell_id']}")
                print(f"Resolution:  {info['resolution']}")
                print(f"Center:      ({info['center_lat']:.6f}, {info['center_lng']:.6f})")
                print(f"Area:        {info['area_km2']:.6f} km²")
                print(f"Is Pentagon: {info['is_pentagon']}")
                if info['parent']:
                    print(f"Parent:      {info['parent']}")
                print(f"Map URL:     https://h3geo.org/#hex={info['cell_id']}")
            
            if args.neighbors:
                neighbors = get_neighbors(args.cell, args.rings)
                print(f"\nNeighbors (k={args.rings}): {len(neighbors)} cells")
                for n in neighbors:
                    print(f"  {n}")
                    
        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
    
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
