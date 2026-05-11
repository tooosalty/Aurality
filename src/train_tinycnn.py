import os
import numpy as np
import pandas as pd
import tensorflow as tf
import librosa

from sklearn.utils import shuffle

# -------------------------
# Config
# -------------------------
SR = 22050
N_MELS = 64              # smaller than 128, helps TinyML constraints
N_FFT = 1024
HOP_LENGTH = 256
DURATION = 5.0           # seconds
FIXED_FRAMES = int(np.ceil((SR * DURATION) / HOP_LENGTH))  # ~431 frames

BATCH_SIZE = 16
EPOCHS = 50
RANDOM_SEED = 42

SPLITS_DIR = "splits"
MODELS_DIR = "models"
RESULTS_DIR = "results"

os.makedirs(MODELS_DIR, exist_ok=True)
os.makedirs(RESULTS_DIR, exist_ok=True)

# Label mapping, align to your chosen numeric convention
LABEL_MAP = {
    "alarm": 0,
    "glass_break": 1,
    "shouting": 2
}

def load_csv(split_name: str) -> pd.DataFrame:
    path = os.path.join(SPLITS_DIR, f"{split_name}.csv")
    df = pd.read_csv(path)
    if "filepath" not in df.columns:
        raise ValueError("CSV must contain a 'filepath' column.")
    if "CLASS" in df.columns:
        df["label"] = df["CLASS"].map(LABEL_MAP)
    elif "label" not in df.columns:
        raise ValueError("CSV must contain either 'CLASS' or 'label' column.")
    return df

def extract_logmel(filepath: str) -> np.ndarray:
    y, _ = librosa.load(filepath, sr=SR, mono=True, duration=DURATION)
    # Pad or trim to exact length
    target_len = int(SR * DURATION)
    if len(y) < target_len:
        y = np.pad(y, (0, target_len - len(y)))
    else:
        y = y[:target_len]

    mel = librosa.feature.melspectrogram(
        y=y,
        sr=SR,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS,
        power=2.0
    )
    logmel = librosa.power_to_db(mel, ref=np.max)

    # Ensure fixed time dimension
    if logmel.shape[1] < FIXED_FRAMES:
        pad_width = FIXED_FRAMES - logmel.shape[1]
        logmel = np.pad(logmel, ((0, 0), (0, pad_width)))
    else:
        logmel = logmel[:, :FIXED_FRAMES]

    # Normalise per-sample to stabilise training
    logmel = (logmel - np.mean(logmel)) / (np.std(logmel) + 1e-8)

    # Add channel dimension for Conv2D: (mels, frames, 1)
    return logmel.astype(np.float32)[..., np.newaxis]

def build_dataset(df: pd.DataFrame, training: bool) -> tf.data.Dataset:
    filepaths = df["filepath"].tolist()
    labels = df["label"].astype(int).tolist()

    def gen():
        for fp, lab in zip(filepaths, labels):
            yield extract_logmel(fp), lab

    ds = tf.data.Dataset.from_generator(
        gen,
        output_signature=(
            tf.TensorSpec(shape=(N_MELS, FIXED_FRAMES, 1), dtype=tf.float32),
            tf.TensorSpec(shape=(), dtype=tf.int32)
        )
    )

    if training:
        ds = ds.shuffle(buffer_size=len(df), seed=RANDOM_SEED, reshuffle_each_iteration=True)

    ds = ds.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)
    return ds

def build_tiny_cnn(input_shape):
    inputs = tf.keras.Input(shape=input_shape)

    x = tf.keras.layers.Conv2D(16, (3,3), padding="same", use_bias=False)(inputs)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.ReLU()(x)
    x = tf.keras.layers.MaxPool2D((2,2))(x)

    x = tf.keras.layers.Conv2D(32, (3,3), padding="same", use_bias=False)(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.ReLU()(x)
    x = tf.keras.layers.MaxPool2D((2,2))(x)

    x = tf.keras.layers.Conv2D(64, (3,3), padding="same", use_bias=False)(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.ReLU()(x)

    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)

    outputs = tf.keras.layers.Dense(3, activation="softmax")(x)

    model = tf.keras.Model(inputs, outputs)
    return model

def main():
    tf.random.set_seed(RANDOM_SEED)
    np.random.seed(RANDOM_SEED)

    train_df = load_csv("train")
    val_df = load_csv("val")

    train_ds = build_dataset(train_df, training=True)
    val_ds = build_dataset(val_df, training=False)

    model = build_tiny_cnn((N_MELS, FIXED_FRAMES, 1))
    model.summary()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=os.path.join(MODELS_DIR, "tinycnn_best.keras"),
            monitor="val_accuracy",
            save_best_only=True
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=10,
            restore_best_weights=True
        )
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks
    )

    model.save(os.path.join(MODELS_DIR, "tinycnn_final.keras"))

    # Save training curves quickly
    import matplotlib.pyplot as plt
    plt.figure()
    plt.plot(history.history["accuracy"], label="train_acc")
    plt.plot(history.history["val_accuracy"], label="val_acc")
    plt.xlabel("epoch")
    plt.ylabel("accuracy")
    plt.legend()
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, "training_accuracy.png"))
    plt.close()

    plt.figure()
    plt.plot(history.history["loss"], label="train_loss")
    plt.plot(history.history["val_loss"], label="val_loss")
    plt.xlabel("epoch")
    plt.ylabel("loss")
    plt.legend()
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, "training_loss.png"))
    plt.close()

    print("Training complete. Saved model and curves.")

if __name__ == "__main__":
    main()