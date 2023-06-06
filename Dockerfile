FROM python:3

# Install dependencies
RUN apt update
RUN apt install -y ffmpeg
RUN pip3 install discord.py python-dotenv pynacl

WORKDIR /usr/src/app
COPY . .

RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp

CMD ["python3", "main.py"]
