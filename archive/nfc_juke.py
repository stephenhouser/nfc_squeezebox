#!/usr/bin/env python3
from pysqueezebox import Server, Player
import csv
import sys
import aiohttp
import asyncio
import aiomqtt
import paho.mqtt as mqtt

TAG_FILE = 'tags.csv'

LMS_SERVER = 'sahmaxi' # ip address of Logitech Media Server
LMS_PLAYER = 'office-mini (squeezelite)'

MQTT_HOST = 'homeassistant'
MQTT_USER = 'm5go'
MQTT_PASS = '_m5go'
MQTT_TOPIC = 'rfid/reader01'

# command = command, parameters = string to send to LMS server
# command = album, parameters = album or playlist path to play (in order)
# command = year, parameters = year to play random songs from
# command = url, parameters = raw url to play

TAGS = {}

def load_tags(fname):
    with open(fname, encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            TAGS[row[0]] = row[1:]

#    for tag in tags:
#        [tp, url] = tags[tag]
#        print(f'tag={tag} is {tp} at {url}')

    return TAGS

async def play_url(player, url):
    await player.async_load_url(url)
    await player.async_update()
    print(f'LMS: Play url {player.album} on player={player.name}')

async def play_album(player, album):
    await player.async_load_url(f'/music/{album}/')
    await player.async_update()
    print(f'LMS: Play album {player.album} on player={player.name}')

async def play_year(player, year):
    await player.async_command('dynamicplaylist', 'playlist', 'play', 
                'dplccustom_play_year', f'dynamicplaylist_parameter_1:{year}')
    await player.async_update()
    print(f'LMS: Play year {year} on player={player.name}')

async def play_command(player, command):
    await player.async_command(*(command.split()))
    await player.async_update()
    print(f'LMS: Send {command} to {player.name}')


async def tag_detected(player, tag):
    if tag not in TAGS:
        print(f'LMS: {tag}: Tag not found')
        return

    if len(TAGS[tag]) > 2:
        (command, parameters, comment) = TAGS[tag]
    else:
        comment = None
        (command, parameters) = TAGS[tag]

    print(f'LMS: {tag}: {command}({parameters}) # {comment}')
    match command:
        case 'quit':
            return
        case 'command':
            await play_command(player, parameters)
        case 'url':
            await play_url(player, parameters)
        case 'album':
            await play_album(player, parameters)
        case 'year':
            await play_year(player, parameters)
        case _:
            print(f'LMS: {tag}: "{command}" command unknown')

async def get_player(lms, player_name):
    players = await lms.async_get_players()
    for player in players:
        if player.name == player_name:
            return player

    return None

async def main():
    player = None

    load_tags(TAG_FILE)
    if len(TAGS) == 0:
        print(f'Cannot load tag configuration.')
        return

    async with aiohttp.ClientSession() as session:
        lms = Server(session, LMS_SERVER)

        player = await get_player(lms, LMS_PLAYER)
        if player == None:
            print(f'Player {LMS_PLAYER} not found.')
            return

        async with aiomqtt.Client(hostname=MQTT_HOST, username=MQTT_USER, password=MQTT_PASS) as client:
            print(f'MQTT: Connected to {MQTT_HOST}.')

            await client.subscribe(f'{MQTT_TOPIC}/#')
            print(f'MQTT: Subscribed to {MQTT_TOPIC}/#')

            async for message in client.messages:
                print(f'MQTT: Received [{message.topic}] {message.payload}')

                if message.topic.matches(f'{MQTT_TOPIC}/tag'):
                    payload = message.payload
                    await tag_detected(player, payload.decode('utf-8'))
                # handle buttons like a special tag with ID of button1
                if message.topic.matches(f'{MQTT_TOPIC}/button1'):
                    await tag_detected(player, 'button1')


if __name__ == '__main__':
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
