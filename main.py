import os
import subprocess

from dotenv import load_dotenv
from functools import partial

import discord

class Client(discord.Client):
    def __init__(self):
        intents = discord.Intents().default()
        intents.members = True
        super().__init__(intents=intents)


    async def on_ready(self):
        print("Logged on as {}".format(self.user))


    async def on_message(self, message: discord.Message):
        if message.author == self.user:
            return

        if message.channel.type is not discord.ChannelType.private:
            return

        url = message.content
        v_id = url.split("=")[1]
        user = message.channel.recipient.id

        # Download file if it doesn't exist already
        if not os.path.exists(v_id):
            subprocess.run(["yt-dlp", "-f", "ba/b", "-o", v_id, url])

        for chan in self.get_all_channels():
            # Check if Channel is Voice Channel
            if type(chan) is not discord.VoiceChannel:
                continue

            # Join the voice channel the user who DM'd Sergei is in
            if user not in [i.id for i in chan.members]:
                continue

            # Try to create a new voice client; grab existing one if available
            try:
                v_client: discord.VoiceClient = await chan.connect()
            except discord.errors.ClientException:
                for client in self.voice_clients:
                    if client.channel.id != chan.id:
                        continue

                    v_client = client
                    await v_client.move_to(chan)
                    v_client.stop()

            self.play(v_client, v_id)


    @staticmethod
    def play(vc: discord.VoiceClient, v_id: str, err=None):
        if err is not None:
            print(err)
            return

        if vc.is_playing():
            return

        audio = discord.FFmpegOpusAudio(v_id)
        vc.play(audio, after=partial(Client.play, vc, v_id))


if __name__ == "__main__":
    load_dotenv()
    Client().run(os.getenv("DISCORD_TOK"))

