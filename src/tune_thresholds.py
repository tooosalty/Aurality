import os
import json
import numpy as np
import pandas as pd
import tensorflow as tf
import librosa

# --- Config ---
SR, N_MELS, N_FFT, HOP_LENGTH, DURATION = 22050, 64, 1024, 256, 5.0
INV_LABEL = {0: "alarm", 1: "glass_break", 2: "shouting"}

def extract_standard_logmel(y, sr=22050):
    """Unified DSP chain to prevent Train-Serve Skew."""
    target_len = int(sr * 5.0)
    y = np.pad(y, (0, max(0, target_len - len(y))))[:target_len]
    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_fft=1024, hop_length=256, n_mels=64)
    logmel = librosa.power_to_db(mel, ref=np.max)
    logmel = (logmel - np.mean(logmel)) / (np.std(logmel) + 1e-8)
    return logmel[np.newaxis, ..., np.newaxis]

def run_inference_on_set(csv_path, model):
    df = pd.read_csv(csv_path)
    results = []
    print("Auditing validation data...")
    for _, row in df.iterrows():
        y, _ = librosa.load(row['filepath'], sr=SR, duration=DURATION)
        # FIX: Call the unified function here!
        feat = extract_standard_logmel(y, SR)
        
        probs = model.predict(feat, verbose=0)[0]
        sorted_indices = np.argsort(probs)[::-1]
        
        results.append({
            "true_class": row['CLASS'],
            "p_alarm": probs[0], "p_glass": probs[1], "p_shouting": probs[2],
            "p1": probs[sorted_indices[0]], "p1_idx": sorted_indices[0],
            "margin": probs[sorted_indices[0]] - probs[sorted_indices[1]]
        })
    return pd.DataFrame(results)

def evaluate_logic(df, tg, ts, ta, delta):
    totals = df["true_class"].value_counts().to_dict()
    hits = {"alarm": 0, "glass_break": 0, "shouting": 0}
    coverage = {"alarm": 0}
    disturbances = 0

    for _, row in df.iterrows():
        if row['p_glass'] >= tg: pred = "glass_break"
        elif row['p_shouting'] >= ts and row['margin'] >= delta: pred = "shouting"
        elif row['p_alarm'] >= ta: pred = "alarm"
        elif row['p1'] >= 0.33: 
            pred = "disturbance"
            disturbances += 1
        else: pred = "none"

        if row['true_class'] == "glass_break" and pred == "glass_break": hits["glass_break"] += 1
        if row['true_class'] == "shouting" and pred == "shouting": hits["shouting"] += 1
        if row['true_class'] == "alarm":
            if pred == "alarm": hits["alarm"] += 1
            if pred in ["alarm", "shouting", "disturbance"]: coverage["alarm"] += 1

    r_g = hits.get("glass_break", 0) / totals.get("glass_break", 1)
    r_s = hits.get("shouting", 0) / totals.get("shouting", 1)
    cov_a = coverage.get("alarm", 0) / totals.get("alarm", 1)
    dist_rate = disturbances / len(df)
    score = (2*r_g + 2*r_s + 1*cov_a) - (0.5 * dist_rate)
    return score, r_g, r_s, cov_a

def main():
    model = tf.keras.models.load_model("models/tinycnn_best.keras")
    val_results = run_inference_on_set("splits/val.csv", model)
    val_results.to_csv("results/val_prob_audit.csv", index=False)
    
    best_score, best_config = -1, {}
    # Grid Sweep
    for tg in np.arange(0.35, 0.60, 0.05):
        for ts in np.arange(0.35, 0.60, 0.05):
            for ta in np.arange(0.35, 0.60, 0.05):
                for delta in np.arange(0.00, 0.10, 0.02):
                    score, rg, rs, ca = evaluate_logic(val_results, tg, ts, ta, delta)
                    if score > best_score:
                        best_score = score
                        best_config = {"tau_g": float(tg), "tau_s": float(ts), "tau_a": float(ta), 
                                       "delta": float(delta), "tau_event": 0.33}

    with open("models/thresholds.json", "w") as f:
        json.dump(best_config, f, indent=4)
    print(f"Optimal Config Saved: {best_config}")

if __name__ == "__main__":
    main()