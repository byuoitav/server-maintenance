import re
import yaml
import socket
import json
import sys
import os
from urllib import request as req

class TeamsWebhookException(Exception):
    pass

# Open the configuration file and dump information into variable
config = 'config.yaml'
with open(config, "r") as configfile:
    cfg = yaml.load(configfile)

TEAMS_WEBHOOK_URL = cfg["comms"]['teams_webhook']

def post_teams_message(message: str) -> None:
    request = req.Request(url=TEAMS_WEBHOOK_URL, method="POST")
    request.add_header(key="Content-Type", val="application/json")
    data = json.dumps({"text": message}).encode()
    with req.urlopen(url=request, data=data) as response:
        if response.status != 200:
            raise TeamsWebhookException(response.reason)

## TODO - do we need to send this information to the event bus - would it be useful
"""
def post_event_bus(message: str) -> None:
    request = req.Request(url=WEBHOOK_URL, method="POST")
    request.add_header(key="Content-Type", val="application/json")
    data = json.dumps({"text": message}).encode()
    with req.urlopen(url=request, data=data) as response:
        if response.status != 200:
            raise TeamsWebhookException(response.reason)
"""

def search_string(file_path, word):
    with open(file_path, 'r') as file:
        output = []
        content = file.readlines()
        for w in content: 
            if word in w:
                print (w.strip())
                output.append(w.strip()) 
        return output

if __name__ == "__main__":

    # Pull the list of files to check
    #mount_check = '/proc/mounts'
    mount_check = cfg["mount_check"]["files"]

    # Pull the list of mount points to check
    #points = ['/dev','/dev/sda1','/dev/loop1']
    points = cfg["mount_points"]

    ro = ' ro,'
    rw = ' rw,'
    missmount = []
    readonly = []
    #post_teams_message("Testing Teams Integration......{}".format(socket.gethostname()))
    hname = socket.gethostname()
    print("Starting storage check....")
    # Loop through and check if multiple mount points are in read only mode

    for mc in mount_check:
        for point in points:
            sp = (point + " ")
            print(sp)
            ret = search_string(mc, sp)
            if len(ret) == 0:
                # Add the mountpoint to a list of missing mounts (in order to create an alert)
                missmount.append(point)
            else:
                for r in ret:
                    z = re.search(ro, r)
                    if z:
                        readonly.append(point)

    # Check if we discovered a missing mountpoint or a mount in read only mode
    # if we discover an issue, raise the flag
    if len(missmount) != 0:
        for m in missmount:
            print('Mount is missing: {}'.format(m))
            post_teams_message("Server {} is missing mount {} and needs immediate attention".format(hname, m))
    if len(readonly) != 0:
        for rdo in readonly:
            print('Mount is in read only mode: {}'.format(rdo))
            post_teams_message("Server {} has a mount {} in readonly mode and needs immediate attention".format(hname, rdo))

    

