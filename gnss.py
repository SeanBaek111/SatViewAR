from flask import Flask, request, jsonify
from skyfield.api import load, Topos
from datetime import datetime, timedelta
from timezonefinder import TimezoneFinder
import pytz
import json
import re

app = Flask(__name__)
host_addr = "0.0.0.0"
host_port = 5001

# Initialise the last download time to a distant past date
#last_download_time = datetime.utcnow() - timedelta(days=1)

# Load the most recent call information from a file
def load_last_calls():
    try:
        with open('last_calls.json', 'r') as file:
            return json.load(file)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

# Save the latest call information to a file
def save_last_calls(calls):
    with open('last_calls.json', 'w') as file:
        json.dump(calls, file)

# Update the most recent call data
def update_last_call(group):
    calls = load_last_calls()
    calls[group] = datetime.utcnow().isoformat()
    save_last_calls(calls)

# Calculate the hours since the last call
def get_hours_since_last_call(group):
    calls = load_last_calls()
    if group not in calls:
        return None  # First time this group has been called
    last_call_time = datetime.fromisoformat(calls[group])
    elapsed_time = datetime.utcnow() - last_call_time
    return elapsed_time.total_seconds() / 3600  # Return in hours

def get_satellite_number(satellite_name):
    # Extract the satellite number from its name using regex
    match = re.search(r'\d+', satellite_name)
    return int(match.group()) if match else 0

@app.route('/')
def hello():
    return "gnss data"

def fetch_satellites(stations_url, group, reload=None):
    """Retrieve satellite data from the specified URL."""

    if reload in [None, False, 'false']:
        # Check if more than 3 hours have passed since the last download
        hours_since_last_call = get_hours_since_last_call(group)
        reload = hours_since_last_call is None or hours_since_last_call > 3
        satellites = load.tle_file(stations_url) 

    if reload in [True, 'true']:
        satellites = load.tle_file(stations_url, reload=True) 
        update_last_call(group)

    return satellites

@app.route('/gnss', methods=['GET'])
def get_gnss_data():
    """Endpoint to retrieve GNSS satellite data based on location."""
    
    # Get query parameters: latitude, longitude, elevation, group, reload
    latitude = float(request.args.get('latitude'))
    longitude = float(request.args.get('longitude'))
    elevation = float(request.args.get('elevation', 0))
    group = request.args.get('group')
    reload = request.args.get('reload')

    groups = [
        'GPS-OPS',
        'glo-ops',
        'beidou',
        'galileo',
        'sbas'
    ]

    satellites = []
    if group == 'all':
        for g in groups:
            stations_url = f'https://celestrak.org/NORAD/elements/gp.php?GROUP={g}&FORMAT=tle'
            satellites.extend([(g, sat) for sat in fetch_satellites(stations_url, g, reload)])
    else:
        stations_url = f'https://celestrak.org/NORAD/elements/gp.php?GROUP={group}&FORMAT=tle'
        satellites.extend([(group, sat) for sat in fetch_satellites(stations_url, group, reload)])

    # Adjust time based on the timezone of the given coordinates
    tz_finder = TimezoneFinder()
    current_utc_time = datetime.utcnow()
    local_timezone_str = tz_finder.timezone_at(lat=latitude, lng=longitude)
    local_timezone = pytz.timezone(local_timezone_str)
    local_time = current_utc_time.replace(tzinfo=pytz.utc).astimezone(local_timezone)
    utc_time_from_local = local_time.astimezone(pytz.utc)

    ts = load.timescale()
    t = ts.utc(utc_time_from_local.year, utc_time_from_local.month, utc_time_from_local.day,
               utc_time_from_local.hour, utc_time_from_local.minute, utc_time_from_local.second)

    observer_location = Topos(latitude_degrees=latitude, longitude_degrees=longitude, elevation_m=elevation)
    results = []

    # Regex to identify PRN numbers in satellite names
    prn_pattern = re.compile(r'PRN E(\d+)|PRN (\d+)|\((\d+)(K)?\)|C(\d+)')

    for group, sat in satellites:
        difference = sat - observer_location
        topocentric = difference.at(t)
        alt, az, d = topocentric.altaz()

        if alt.degrees > 0:
            prn_match = prn_pattern.search(sat.name)
            if prn_match:
                prn_number = (
                    prn_match.group(1)
                    or prn_match.group(2)
                    or prn_match.group(3)
                    or prn_match.group(5) 
                )
            else:
                continue

            # Determine satellite type prefix
            sat_type = {
                "GPS-OPS": "GPS G",
                "glo-ops": "GLONASS R",
                "beidou": "BeiDou B",
                "galileo": "Galileo E",
                "sbas": "SBAS S"
            }.get(group, None)

            if sat_type:
                results.append({
                    "satellite": f"{sat_type}{prn_number}",
                    "azimuth": az.degrees,
                    "elevation": alt.degrees
                })

    # Function to extract sorting keys
    def get_sort_keys(item):
        system, code_number = item['satellite'].split(' ')
        number = int(code_number[1:])
        return (system, code_number[0], number)

    sorted_data = sorted(results, key=get_sort_keys)

    return jsonify(sorted_data)

@app.route('/ping')
def ping():
    """Health check endpoint. Confirms if the server is operational."""
    return {'response': 'pong'}

if __name__ == "__main__":
    app.run(debug=True, host=host_addr, port=host_port)
