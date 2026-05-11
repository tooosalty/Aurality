import os
import numpy as np
import pandas as pd
import tensorflow as tf
import librosa
import matplotlib.pyplot as plt

from sklearn.metrics import classification_report, confusion_matrix, ConfusionMatrixDisplay

SR = 22050
N_MELS = 64
N_FFT = 1024
HOP_LENGTH = 256
DURATION = 5.0
FIXED_FRAMES = int(np.ceil((SR * DURATION) / HOP_LENGTH))

LABEL_MAP = {"alarm": 0, "glass_break": 1, "shouting": 2}
INV_LABEL = {v: k for k, v in LABEL_MAP.items()}

SPLITS_DIR = "splits"
MODELS_DIR = "models"
RESULTS_DIR = "results"
os.makedirs(RESULTS_DIR, exist_ok=True)

def extract_logmel(filepath: str) -> np.ndarray:
    y, _ = librosa.load(filepath, sr=SR, mono=True, duration=DURATION)
    target_len = int(SR * DURATION)
    if len(y) < target_len:
        y = np.pad(y, (0, target_len - len(y)))
    else:
        y = y[:target_len]

    mel = librosa.feature.melspectrogram(
        y=y, sr=SR, n_fft=N_FFT, hop_length=HOP_LENGTH, n_mels=N_MELS, power=2.0
    )
    logmel = librosa.power_to_db(mel, ref=np.max)

    if logmel.shape[1] < FIXED_FRAMES:
        logmel = np.pad(logmel, ((0,0), (0, FIXED_FRAMES - logmel.shape[1])))
    else:
        logmel = logmel[:, :FIXED_FRAMES]

    logmel = (logmel - np.mean(logmel)) / (np.std(logmel) + 1e-8)
    return logmel.astype(np.float32)[..., np.newaxis]

def main():
    df = pd.read_csv(os.path.join(SPLITS_DIR, "test.csv"))
    if "CLASS" in df.columns:
        y_true = df["CLASS"].map(LABEL_MAP).astype(int).to_numpy()
    else:
        y_true = df["label"].astype(int).to_numpy()

    X = np.stack([extract_logmel(fp) for fp in df["filepath"].tolist()], axis=0)

    model = tf.keras.models.load_model(os.path.join(MODELS_DIR, "tinycnn_v2_best.keras"))
    probs = model.predict(X, verbose=0)
    y_pred = np.argmax(probs, axis=1)

    target_names = [INV_LABEL[i] for i in range(3)]
    report = classification_report(y_true, y_pred, target_names=target_names, digits=3)
    print(report)

    with open(os.path.join(RESULTS_DIR, "test_classification_report.txt"), "w") as f:
        f.write(report)

    cm = confusion_matrix(y_true, y_pred, labels=[0,1,2])
    disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=target_names)
    disp.plot(values_format="d")
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, "confusion_matrix.png"))
    plt.close()

    print("Saved report and confusion matrix to results/")

if __name__ == "__main__":
    main()