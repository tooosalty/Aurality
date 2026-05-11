import numpy as np
import sounddevice as sd
import tensorflow as tf
import librosa
import json
import os
import soundfile as sf
import datetime
# Import your new module
from firebase_publisher import publish_alert, init_firebase

# --- 1. Load Model & Config ---
model = tf.keras.models.load_model("models/tinycnn_best.keras")
with open("models/thresholds.json", "r") as f:
    T = json.load(f)

# --- 2. Params ---
SR = 22050
WINDOW_SIZE = int(SR * 5.0)
audio_buffer = np.zeros(WINDOW_SIZE, dtype=np.float32)

# State Counters
shouting_counter = 0
alarm_drift_counter = 0

if not os.path.exists('temp'):
    os.makedirs('temp')

def extract_standard_logmel(y, sr=22050):
    target_len = int(sr * 5.0)
    y = np.pad(y, (0, max(0, target_len - len(y))))[:target_len]
    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_fft=1024, hop_length=256, n_mels=64)
    logmel = librosa.power_to_db(mel, ref=np.max)
    logmel = (logmel - np.mean(logmel)) / (np.std(logmel) + 1e-8)
    return logmel[np.newaxis, ..., np.newaxis]

def spectral_heuristic(y):
    centroid = librosa.feature.spectral_centroid(y=y, sr=SR)[0]
    return np.var(centroid) < 1.5e6 

def process_5s_window(y):
    global shouting_counter, alarm_drift_counter
    
    feat = extract_standard_logmel(y, SR)
    probs = model.predict(feat, verbose=0)[0]
    p1_idx = np.argmax(probs)
    sorted_probs = sorted(probs)
    margin = sorted_probs[-1] - sorted_probs[-2]

    final_alert = "Normal"
    should_push = False

    # --- 1. Logic Tree ---
    if probs[1] >= T['tau_g']:
        final_alert = "GLASS_BREAK"
        should_push = True
        shouting_counter = 0 
    
    elif probs[2] >= T['tau_s'] and margin >= T['delta']:
        shouting_counter += 1
        alarm_drift_counter += 1
        if shouting_counter >= 2:
            final_alert = "SHOUTING"
            should_push = True
            if alarm_drift_counter >= 3 and spectral_heuristic(y):
                final_alert = "ALARM"
    
    elif probs[p1_idx] >= T['tau_event']:
        final_alert = "DISTURBANCE"
        should_push = True
        shouting_counter = 0
        alarm_drift_counter = 0
    else:
        final_alert = "Quiet"
        shouting_counter = 0
        alarm_drift_counter = 0

    print(f"[{final_alert}] Shouts: {shouting_counter} | Conf: {probs[p1_idx]:.2f}")
    
    # --- 2. Push to Cloud ---
    if should_push and final_alert != "Quiet":
        # Save clip locally first
        local_path = f"temp/latest_capture.wav"
        sf.write(local_path, y, SR)
        
        probs_dict = {
            "alarm": float(probs[0]),
            "glass": float(probs[1]),
            "shouting": float(probs[2])
        }
        
        # Call the external publisher module
        try:
            doc_id = publish_alert(
                event_type=final_alert,
                confidence=probs[p1_idx],
                local_audio_path=local_path,
                all_probs=probs_dict,
                margin=margin
            )
            print(f"☁️ Cloud Sync Success: {doc_id}")
        except Exception as e:
            print(f"❌ Cloud Sync Failed: {e}")
            
        if os.path.exists(local_path):
            os.remove(local_path)

def audio_callback(indata, frames, time, status):
    global audio_buffer
    audio_buffer = np.roll(audio_buffer, -len(indata))
    audio_buffer[-len(indata):] = indata.flatten()

# --- Execution ---
print("Aurality Edge System Active...")
with sd.InputStream(samplerate=SR, channels=1, callback=audio_callback):
    while True:
        sd.sleep(2500) # Process every 2.5s for 50% window overlap
        process_5s_window(audio_buffer)