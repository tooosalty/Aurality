import os
import numpy as np
import pandas as pd
import tensorflow as tf
import librosa

# Config (Matches your V1 setup)
SR = 22050
N_MELS = 64
N_FFT = 1024
HOP_LENGTH = 256
DURATION = 5.0
FIXED_FRAMES = int(np.ceil((SR * DURATION) / HOP_LENGTH))
LABEL_MAP = {"alarm": 0, "glass_break": 1, "shouting": 2}
INV_LABEL = {v: k for k, v in LABEL_MAP.items()}

def extract_logmel(filepath):
    y, _ = librosa.load(filepath, sr=SR, mono=True, duration=DURATION)
    target_len = int(SR * DURATION)
    if len(y) < target_len:
        y = np.pad(y, (0, target_len - len(y)))
    else:
        y = y[:target_len]
    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_fft=N_FFT, hop_length=HOP_LENGTH, n_mels=N_MELS)
    logmel = librosa.power_to_db(mel, ref=np.max)
    logmel = (logmel - np.mean(logmel)) / (np.std(logmel) + 1e-8)
    return logmel.astype(np.float32)[..., np.newaxis]

def main():
    # Load V1 Model
    model = tf.keras.models.load_model("models/tinycnn_best.keras")
    df = pd.read_csv("splits/test.csv")
    
    print(f"{'True Class':<15} | {'Pred Class':<15} | {'Confidence':<10} | {'Status'}")
    print("-" * 60)

    for _, row in df.iterrows():
        feat = extract_logmel(row['filepath'])
        preds = model.predict(feat[np.newaxis, ...], verbose=0)[0]
        
        pred_idx = np.argmax(preds)
        confidence = preds[pred_idx]
        true_label = row['CLASS']
        pred_label = INV_LABEL[pred_idx]
        
        status = "CORRECT" if true_label == pred_label else "MISMATCH"
        print(f"{true_label:<15} | {pred_label:<15} | {confidence:.4f}     | {status}")

if __name__ == "__main__":
    main()