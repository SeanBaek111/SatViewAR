from flask import Flask, request, jsonify
from skyfield.api import load, Topos
from datetime import datetime, timedelta
from timezonefinder import TimezoneFinder
import pytz

app = Flask(__name__)
host_addr = "0.0.0.0"
host_port = 5001

# Initialize the last_download_time to a time far in the past
last_download_time = datetime.utcnow() - timedelta(days=1)


@app.route('/')
def hello():
    """Root route. Responds to access attempts with a guidance message."""
    return "try /ping!"

def fetch_satellites(stations_url):
    """Fetches satellite data from the given URL."""
    global last_download_time

    # Check if it's been more than 3 hours since the last download
    should_reload = datetime.utcnow() - last_download_time > timedelta(hours=3)

    satellites = load.tle_file(stations_url, reload=should_reload)

    # If data was reloaded, update the last download time
    if should_reload:
        last_download_time = datetime.utcnow()

    return satellites
    
@app.route('/gnsstest', methods=['GET'])
def get_gnss_datatest():
    """Endpoint to test satellite data fetching."""
    
    # Retrieve query parameters: latitude, longitude, and elevation.
    latitude = float(request.args.get('latitude'))
    longitude = float(request.args.get('longitude'))
    elevation = float(request.args.get('elevation', 0))

    #stations_url = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=galileo&FORMAT=tle'
    stations_url = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=gnss&FORMAT=tle'
    satellites = fetch_satellites(stations_url)

    # Serialize satellite objects for response.
    serialized_sats = []
    for sat in satellites:
        serialized_sats.append({
            'name': sat.name,
        })

    return jsonify(serialized_sats)

@app.route('/gnss', methods=['GET'])
def get_gnss_data():
    """Endpoint to get GNSS satellite data based on location."""
    
    # Retrieve query parameters: latitude, longitude, and elevation.
    latitude = float(request.args.get('latitude'))
    longitude = float(request.args.get('longitude'))
    elevation = float(request.args.get('elevation', 0))

    # Satellite data source URL.
    ##stations_url = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=galileo&FORMAT=tle'
    stations_url = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=gnss&FORMAT=tle'
    satellites = fetch_satellites(stations_url)

    # Adjusting the time based on the timezone of the provided coordinates.
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

    # Iterate over satellites and filter those visible from the observer's location.
    for sat in satellites:
        difference = sat - observer_location
        topocentric = difference.at(t)
        alt, az, d = topocentric.altaz()
        if alt.degrees > 0:
            results.append({
                "satellite": sat.name,
                "azimuth": az.degrees,
                "elevation": alt.degrees
            })

    return jsonify(results)

@app.route('/ping')
def ping():
    """Endpoint for health check. Responds to confirm server is running."""
    return {'response': 'pong'}

if __name__ == "__main__":
    app.run(debug=True, host=host_addr, port=host_port)
