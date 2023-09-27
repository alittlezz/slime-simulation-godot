#!/usr/bin/env python3

# required libraries
from scipy.io import wavfile
import pydub
from scipy import signal
import numpy as np
import matplotlib.pyplot as plt


def spectral_centroid(x, samplerate=44100):
    magnitudes = np.abs(np.fft.rfft(x))  # magnitudes of positive frequencies
    length = len(x)
    freqs = np.abs(
        np.fft.fftfreq(length, 1.0 / samplerate)[: length // 2 + 1]
    )  # positive frequencies
    return magnitudes, freqs


sound_file = "vivaldi-winter"
mp3 = pydub.AudioSegment.from_mp3(f"{sound_file}.mp3")
mp3.export(f"{sound_file}.wav", format="wav")
rate, aud_data = wavfile.read(f"{sound_file}.wav")
channel, _ = spectral_centroid(aud_data, rate)
# print("Got song duration", duration_millis // 1000)
# print("Got channels", aud_data.ndim)
channel = channel[:, 0]  # left
duration_millis = len(channel) * 1000 // float(rate)
## channel2 = channel[:, 1]  # right
#
## channel = (channel1 + channel2) / 2
while channel.size % duration_millis != 0:
    duration_millis -= 1
print("Batches of size", channel.size // duration_millis)
channel = np.max(channel.reshape(-1, int(channel.size // duration_millis)), axis=1)
channel = (channel - np.min(channel)) / (np.max(channel) - np.min(channel))
# channel = np.array(list(map(lambda x: max(x, 0.5), channel)))
np.savetxt(f"{sound_file}-freq.txt", channel)
print(len(channel))

plt.plot([i for i in range(len(channel))], channel)
plt.show()
