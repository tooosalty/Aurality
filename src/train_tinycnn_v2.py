import os
import numpy as np
import pandas as pd
import tensorflow as tf
import librosa
from tensorflow.keras import layers, models
from pathlib import Path

# -------------------------
# Config (Optimized for Iteration 2)
# -------------------------
SR = 22050
N_MELS = 64
N_FFT = 1024
HOP_LENGTH = 256
DURATION = 5.0
FIXED_FRAMES = int(np.ceil((SR * DURATION) / HOP_LENGTH))

BATCH_SIZE = 8 
EPOCHS = 70    
RANDOM_SEED = 42

SPLITS_DIR = "splits"
MODELS_DIR = "models"
RESULTS_DIR = "results"

LABEL_MAP = {"alarm": 0, "glass_break": 1, "shouting": 2}

# -------------------------
# Helpers & Augmentation
# -------------------------
def load_csv(split_name: str) -> pd.DataFrame:
    path = os.path.join(SPLITS_DIR, f"{split_name}.csv")
    df = pd.read_csv(path)
    df["label"] = df["CLASS"].map(LABEL_MAP)
    return df

def augment_audio(y):
    # Noise injection to improve robust features
    noise = np.random.randn(len(y))
    return y + 0.005 * noise

def extract_logmel(filepath: str, augment: bool) -> np.ndarray:
    y, _ = librosa.load(filepath, sr=SR, mono=True, duration=DURATION)
    target_len = int(SR * DURATION)
    
    # Standardize length
    if len(y) < target_len:
        y = np.pad(y, (0, target_len - len(y)))
    else:
        y = y[:target_len]

    if augment:
        y = augment_audio(y)

    mel = librosa.feature.melspectrogram(y=y, sr=SR, n_fft=N_FFT, hop_length=HOP_LENGTH, n_mels=N_MELS)
    logmel = librosa.power_to_db(mel, ref=np.max)
    logmel = (logmel - np.mean(logmel)) / (np.std(logmel) + 1e-8)
    return logmel.astype(np.float32)[..., np.newaxis]

def build_dataset(df: pd.DataFrame, training: bool) -> tf.data.Dataset:
    filepaths = df["filepath"].tolist()
    labels = df["label"].tolist()

    def gen():
        for fp, lab in zip(filepaths, labels):
            # Only augment training data, never validation/test data
            yield extract_logmel(fp, augment=training), lab

    return tf.data.Dataset.from_generator(
        gen,
        output_signature=(
            tf.TensorSpec(shape=(N_MELS, FIXED_FRAMES, 1), dtype=tf.float32),
            tf.TensorSpec(shape=(), dtype=tf.int32)
        )
    ).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

# -------------------------
# Improvement A: 4-Block Tiny CNN
# -------------------------
def build_tiny_cnn_v2(input_shape):
    model = models.Sequential([
        layers.Input(shape=input_shape),
        
        layers.Conv2D(16, (3,3), padding="same", activation="relu"),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2,2)),

        layers.Conv2D(32, (3,3), padding="same", activation="relu"),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2,2)),

        layers.Conv2D(64, (3,3), padding="same", activation="relu"),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2,2)),

        # The 4th Block for better discriminative power
        layers.Conv2D(64, (3,3), padding="same", activation="relu"),
        layers.BatchNormalization(),
        
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.4), 
        layers.Dense(3, activation="softmax")
    ])
    return model

def main():
    tf.random.set_seed(RANDOM_SEED)
    np.random.seed(RANDOM_SEED)

    train_df = load_csv("train")
    val_df = load_csv("val")

    train_ds = build_dataset(train_df, training=True)
    val_ds = build_dataset(val_df, training=False)

    # Use the V2 model
    model = build_tiny_cnn_v2((N_MELS, FIXED_FRAMES, 1))
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=os.path.join(MODELS_DIR, "tinycnn_v2_best.keras"),
            monitor="val_accuracy",
            save_best_only=True
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=15, # Slightly more patience for augmented training
            restore_best_weights=True
        )
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks
    )

    model.save(os.path.join(MODELS_DIR, "tinycnn_v2_final.keras"))
    print("V2 Training complete.")

if __name__ == "__main__":
    main()