import os
from pathlib import Path
import random
import pandas as pd
import numpy as np

import librosa
import librosa.display
import matplotlib.pyplot as plt


# -------------------------
# CONFIG
# -------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATASET_LOG_PATH = PROJECT_ROOT / "docs" / "dataset_log.xlsx"

PROCESSED_DIR = PROJECT_ROOT / "data" / "processed"
SPLITS_DIR = PROJECT_ROOT / "splits"
RESULTS_DIR = PROJECT_ROOT / "results"

SEED = 42

# Your discrete, stratified split per class (total 30 per class)
N_TRAIN_PER_CLASS = 21
N_VAL_PER_CLASS = 4
N_TEST_PER_CLASS = 5

# Audio feature parameters (align with your preprocessing: 22050 Hz, 5s clips)
SR = 22050
N_MELS = 128
N_FFT = 2048
HOP_LENGTH = 512


# -------------------------
# HELPERS
# -------------------------
def ensure_dirs():
    SPLITS_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def build_file_path(class_name: str, filename: str) -> Path:
    """
    Constructs the expected path for a processed wav file.
    Example: data/processed/glass_break/<filename>
    """
    return PROCESSED_DIR / class_name / filename


def sanity_check_counts(df: pd.DataFrame):
    counts = df["CLASS"].value_counts().to_dict()
    print("Class counts in INCLUDED=Y log:", counts)

    for cls in ["glass_break", "alarm", "shouting"]:
        if counts.get(cls, 0) != 30:
            raise ValueError(
                f"Expected 30 samples for class '{cls}', found {counts.get(cls, 0)}. "
                "Fix your dataset_log.xlsx or INCLUDED flags before splitting."
            )


def stratified_split(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Performs a stratified split by selecting fixed counts per class.
    Uses a fixed seed for reproducibility.
    """
    random.seed(SEED)

    train_rows = []
    val_rows = []
    test_rows = []

    for cls, group in df.groupby("CLASS"):
        items = group.sample(frac=1, random_state=SEED).reset_index(drop=True)

        if len(items) != (N_TRAIN_PER_CLASS + N_VAL_PER_CLASS + N_TEST_PER_CLASS):
            raise ValueError(
                f"Class '{cls}' has {len(items)} items, but expected "
                f"{N_TRAIN_PER_CLASS + N_VAL_PER_CLASS + N_TEST_PER_CLASS}."
            )

        train_part = items.iloc[:N_TRAIN_PER_CLASS]
        val_part = items.iloc[N_TRAIN_PER_CLASS:N_TRAIN_PER_CLASS + N_VAL_PER_CLASS]
        test_part = items.iloc[N_TRAIN_PER_CLASS + N_VAL_PER_CLASS:]

        train_rows.append(train_part)
        val_rows.append(val_part)
        test_rows.append(test_part)

    train_df = pd.concat(train_rows).sample(frac=1, random_state=SEED).reset_index(drop=True)
    val_df = pd.concat(val_rows).sample(frac=1, random_state=SEED).reset_index(drop=True)
    test_df = pd.concat(test_rows).sample(frac=1, random_state=SEED).reset_index(drop=True)

    return train_df, val_df, test_df


def add_paths(df: pd.DataFrame) -> pd.DataFrame:
    """
    Adds absolute file paths to each row based on CLASS and FILENAME.
    Also checks for missing files.
    """
    paths = []
    missing = []

    for _, row in df.iterrows():
        cls = row["CLASS"]
        fname = row["FILENAME"]
        p = build_file_path(cls, fname)
        paths.append(str(p))

        if not p.exists():
            missing.append(str(p))

    out = df.copy()
    out["filepath"] = paths

    if missing:
        print("\nWARNING: Some processed files were not found:")
        for m in missing[:20]:
            print("  -", m)
        if len(missing) > 20:
            print(f"  ... and {len(missing) - 20} more")
        print("\nFix the file paths or filenames before training.")

    return out


def save_split_csv(df: pd.DataFrame, name: str):
    out_path = SPLITS_DIR / f"{name}.csv"
    df.to_csv(out_path, index=False)
    print(f"Saved {name} split to: {out_path}")


def save_example_melspectrogram(df: pd.DataFrame, class_name: str):
    """
    Saves one mel spectrogram image for a given class for dissertation evidence.
    """
    sample = df[df["CLASS"] == class_name].iloc[0]
    wav_path = Path(sample["filepath"])

    y, sr = librosa.load(wav_path, sr=SR, mono=True)
    S = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=N_MELS, n_fft=N_FFT, hop_length=HOP_LENGTH)
    S_db = librosa.power_to_db(S, ref=np.max)

    plt.figure()
    librosa.display.specshow(S_db, sr=sr, hop_length=HOP_LENGTH, x_axis="time", y_axis="mel")
    plt.colorbar(format="%+2.0f dB")
    plt.title(f"Log-Mel Spectrogram Example: {class_name}")
    plt.tight_layout()

    out_img = RESULTS_DIR / f"melspec_example_{class_name}.png"
    plt.savefig(out_img, dpi=200)
    plt.close()
    print(f"Saved mel spectrogram image: {out_img}")


# -------------------------
# MAIN
# -------------------------
def main():
    ensure_dirs()

    df = pd.read_excel(DATASET_LOG_PATH)

    # Keep only included rows
    df = df[df["INCLUDED"].astype(str).str.upper() == "Y"].copy()

    # Minimal required columns
    required = {"CLASS", "FILENAME"}
    if not required.issubset(set(df.columns)):
        raise ValueError(f"dataset_log.xlsx must contain columns: {required}. Found: {list(df.columns)}")

    sanity_check_counts(df)

    # Create splits
    train_df, val_df, test_df = stratified_split(df)

    # Add file paths and label indices
    label_map = {"glass_break": 0, "alarm": 1, "shouting": 2}

    train_df = add_paths(train_df)
    val_df = add_paths(val_df)
    test_df = add_paths(test_df)

    train_df["label"] = train_df["CLASS"].map(label_map)
    val_df["label"] = val_df["CLASS"].map(label_map)
    test_df["label"] = test_df["CLASS"].map(label_map)

    # Save
    save_split_csv(train_df, "train")
    save_split_csv(val_df, "val")
    save_split_csv(test_df, "test")

    # Save one example spectrogram per class (use train split to avoid peeking at test)
    for cls in ["glass_break", "alarm", "shouting"]:
        save_example_melspectrogram(train_df, cls)

    print("\nDone. Next step is building the baseline CNN using these splits.")


if __name__ == "__main__":
    main()