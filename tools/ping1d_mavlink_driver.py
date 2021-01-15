#!/usr/bin/python -u

""" Request distance measurements from a Blue Robotics Ping1D device over udp (PingProxy)
    Send results to autopilot via mavproxy over udp for use as mavlink rangefinder
    Don't request if we are already getting data from device (ex. there is another client
    (pingviewer gui) making requests to the proxy)
"""

import argparse
import errno
import socket
import time
import requests

from pymavlink import mavutil
from brping import PingMessage
from brping import PingParser
from brping import PING1D_DISTANCE, PING1D_DISTANCE_SIMPLE, PING1D_PROFILE

PARSER = argparse.ArgumentParser(description="Ping1D to mavlink bridge.")
PARSER.add_argument('--ping',
                    action="store",
                    type=str,
                    default="0.0.0.0:9090",
                    help="Ping device udp address and port. ex \"0.0.0.0:9090\""
                    )
PARSER.add_argument('--mavlink',
                    action="store",
                    type=str,
                    default="0.0.0.0:9000",
                    help="Mavlink udp address and port. ex \"0.0.0.0:9000\""
                    )
PARSER.add_argument('--min-confidence',
                    action="store",
                    type=int,
                    default=0,
                    help="Minimum acceptable confidence percentage for depth measurements.\""
                    )
ARGS = PARSER.parse_args()

MAVLINK2REST_URL = "http://192.168.2.2:4777"

def set_param(param_name, param_type, param_value):
    """
    Sets parameter "param_name" of type param_type to value "value" in the autopilot
    Returns True if succesful, False otherwise
    """
    try:
        data = requests.get(MAVLINK2REST_URL + '/helper/message/PARAM_SET').json()

        for i, char in enumerate(param_name):
            data["message"]["param_id"][i] = char

        data["message"]["param_type"] = {"type": param_type}
        data["message"]["param_value"] = param_value

        result = requests.post(MAVLINK2REST_URL + '/mavlink', json=data)
        return result.status_code == 200
    except Exception as error:
        print("Error setting parameter: " + str(error))
        return False


def main():
    """ Main function
    """

    if not is_compatible_ardusub_version():
        exit(-1)

    ## Set RNGFND1_TYPE to MavLink
    ## This file will only run if ping1d is detected, so we don't need to check for its presence again
    if not set_param("RNGFND1_TYPE", "MAV_PARAM_TYPE_UINT8", 10):
        print("Failed to set RNGFND_TYPE to MavLink!")

    ## The time that this script was started
    tboot = time.time()

    ## Parser to decode incoming PingMessage
    ping_parser = PingParser()

    ## Messages that have the current distance measurement in the payload
    distance_messages = [
        PING1D_DISTANCE,
        PING1D_DISTANCE_SIMPLE,
        PING1D_PROFILE
        ]

    ## The minimum interval time for distance updates to the autopilot
    ping_interval_ms = 0.075

    ## The last time a distance measurement was received
    last_distance_measurement_time = 0

    ## The last time a distance measurement was requested
    last_ping_request_time = 0

    pingargs = ARGS.ping.split(':')
    pingserver = (pingargs[0], int(pingargs[1]))

    autopilot_io = mavutil.mavlink_connection("udpout:" + ARGS.mavlink,
                                              source_system=1,
                                              source_component=192
                                              )

    ping1d_io = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    ping1d_io.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    ping1d_io.setblocking(False)

    ## Send a request for distance_simple message to ping device
    def send_ping1d_request():
        data = PingMessage()
        data.request_id = PING1D_DISTANCE_SIMPLE
        data.src_device_id = 0
        data.pack_msg_data()
        ping1d_io.sendto(data.msg_data, pingserver)

    # some extra information for the DISTANCE_SENSOR mavlink message fields
    min_distance = 20
    max_distance = 5000
    sensor_type = 2
    orientation = 25
    covarience = 0

    ## Send distance_sensor message to autopilot
    def send_distance_data(distance, deviceid, confidence):
        print("sending distance %d confidence %d" % (distance, confidence))
        if confidence < ARGS.min_confidence:
            distance = 0

        autopilot_io.mav.distance_sensor_send(
            int((time.time() - tboot) * 1000), # time_boot_ms
            min_distance, # min_distance
            max_distance, # max_distance
            int(distance/10), # distance
            sensor_type, # type
            deviceid, # device id
            orientation,
            covarience)

    while True:
        time.sleep(0.001)
        tnow = time.time()

        # request data from ping device
        if tnow > last_distance_measurement_time + ping_interval_ms:
            if tnow > last_ping_request_time + ping_interval_ms:
                last_ping_request_time = time.time()
                send_ping1d_request()

        # read data in from ping device
        try:
            data, _ = ping1d_io.recvfrom(4096)
        except socket.error as exception:
            # check if it's waiting for data
            if exception.errno != errno.EAGAIN:
                raise exception
            else:
                continue

        # decode data from ping device, forward to autopilot
        for byte in data:
            if ping_parser.parse_byte(byte) == PingParser.NEW_MESSAGE:
                if ping_parser.rx_msg.message_id in distance_messages:
                    last_distance_measurement_time = time.time()
                    distance = ping_parser.rx_msg.distance
                    deviceid = ping_parser.rx_msg.src_device_id
                    confidence = ping_parser.rx_msg.confidence
                    send_distance_data(distance, deviceid, confidence)


def is_compatible_ardusub_version():
    """
    Checks if the running ardusub version is 4.0.0 or newer
    (4.0.0 disabled use of rangefinder for depth control)
    """
    while True:
        r = requests.get('http://127.0.0.1:4777/mavlink/AUTOPILOT_VERSION/flight_sw_version')
        # TO-DO: fix next line when https://github.com/patrickelectric/mavlink2rest/issues/3 is solved
        if "No valid path" in r.text or r.status_code == 404:
            print("could not read firmware version, retrying in 5 seconds...")
            time.sleep(5)
            continue
        flight_sw_version = r.json()
        majorVersion = (flight_sw_version >> (8*3)) & 0xFF # bit-fu to extract major version
        if majorVersion < 4:
            print("This driver requires ardusub >= 4.0.0, halting...")
            return False
        print("Valid ardusub version found, starting code...")
        return True

if __name__ == '__main__':
    main()
