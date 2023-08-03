import re
import socket
import json
import sys
import os
from urllib import request as req

class TeamsWebhookException(Exception):
    pass

TEAMS_WEBHOOK_URL = os.environ['TEAMS_WEBHOOK']

def post_teams_message(message: str) -> None:
    request = req.Request(url=TEAMS_WEBHOOK_URL, method="POST")
    request.add_header(key="Content-Type", val="application/json")
    data = json.dumps({"text": message}).encode()
    with req.urlopen(url=request, data=data) as response:
        if response.status != 200:
            raise TeamsWebhookException(response.reason)

# TODO - do we need to send this information to the event bus - would it be useful
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
    mount_check = '/proc/mounts'
    points = ['/dev/mapper/os-Wowzacontent','/dev/sda1']
    ro = ' ro,'
    rw = ' rw,'
    missmount = []
    readonly = []
    #post_teams_message("Testing Teams Integration......{}".format(socket.gethostname()))
    hname = socket.gethostname()
    print("Starting storage check....")
    # Loop through and check if multiple mount points are in read only mode
    for point in points:
        sp = (point + " ")
        print(sp)
        ret = search_string(mount_check, sp)
        if len(ret) == 0:
            # Add the mountpoint to a list of missing mounts (in order to create an alert)
            missmount.append(point)
        else:
            for r in ret:
                z = re.search(ro, r)
                if z:
                    # TODO: Add additional checking logic here to test whether the mount
                    # is really in read only mode
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

    

