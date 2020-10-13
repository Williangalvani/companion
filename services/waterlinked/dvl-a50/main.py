#!/usr/bin/env python3
"""
Driver for the Waterlinked DVL A-50
"""

from flask import Flask
from dvl import DvlDriver
import json

app = Flask(__name__)
thread = None


class API:

    dvl = None

    def __init__(self, dvl: DvlDriver):
        self.dvl = dvl

    def get_status(self) -> str:
        """
        Returns the driver status as a JSON containing the keys
        status, orientation, hostname, and enabled
        """
        return json.dumps(self.dvl.get_status())

    def set_enabled(self, enabled: str) -> bool:
        """
        Enables/Disables the DVL driver
        """
        if enabled in ["true", "false"]:
            return self.dvl.set_enabled(enabled == "true")
        return False

    def set_orientation(self, orientation: int) -> bool:
        """
        Sets the DVL mounting orientation:
        1 = Down
        2 = Forward
        """
        return self.dvl.set_orientation(orientation)

    def set_hostname(self, hostname: str) -> bool:
        """
        Sets the Hostname or IP where the driver tries to connect to the DVL
        """
        return self.dvl.set_hostname(hostname)

    def set_gps_origin(self, lat: str, lon: str) -> bool:
        """
        Sets the EKF origin to lat, lon
        """
        return self.dvl.set_gps_origin(lat, lon)

    def set_use_as_rangefinder(self, enabled: str) -> bool:
        """
        Enables/disables usage of DVL as rangefinder
        """
        if enabled in ["true", "false"]:
            return self.dvl.set_use_as_rangefinder(enabled == "true")
        return False


if __name__ == '__main__':
    dvl = DvlDriver()
    api = API(dvl)

    @app.route('/get_status')
    def get_status():
        return api.get_status()

    @app.route('/enable/<enable>')
    def set_enabled(enable: str):
        return str(api.set_enabled(enable))

    @app.route('/use_as_rangefinder/<enable>')
    def set_use_rangefinder(enable: str):
        return str(api.set_use_as_rangefinder(enable))

    @app.route('/orientation/<int:orientation>')
    def set_orientation(orientation: int):
        return str(api.set_orientation(orientation))

    @app.route('/hostname/<hostname>')
    def set_hostname(hostname):
        return str(api.set_hostname(hostname))

    @app.route('/origin/<lat>/<lon>')
    def set_gps_origin(lat, lon):
        return str(api.set_gps_origin(lat, lon))

    dvl.start()
    app.run(port=9001)
