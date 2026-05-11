Aurality — Real-Time Acoustic Safeguarding System

**Student:** Hendrick Sonfack | S22226209 | CMP6200 Individual Honours Project
**Institution:** Birmingham City University
**Academic Year:** 2025/26

## Project Overview

Aurality is a privacy-preserving acoustic detection system for children's residential care.
A lightweight TinyCNN classifier detects glass breaking, alarms, and shouting on-device.
When an alert is validated, the system uploads a short event-triggered evidence clip and
structured alert metadata to Firebase for authenticated caregiver review.

## Development Environment

| Component | Version |
|---|---|
| Hardware | MacBook Air M2, 8 GB RAM |
| OS | macOS Tahoe |
| Python | 3.9.6 |
| TensorFlow | 2.16.2 |
| Keras | 3.10.0 |
| Librosa | 0.11.0 |
| Flutter | 3.41.2 |
| Firebase Admin SDK | 7.1.0 |

## Repository Structure
Aurality - IUP/
├── data/               # Raw, processed, and source audio (three-tier provenance)
├── splits/             # train.csv, val.csv, test.csv (seed=42, 70/15/15 split)
├── scripts/            # process_audio.py, create_splits.py
├── src/                # Model training, evaluation, threshold calibration, inference
├── models/             # Trained model checkpoints and thresholds.json
├── results/            # Confusion matrices, training curves, classification report
├── docs/               # dataset_log.xlsx (clip-level provenance catalogue)
├── aurality_monitor/   # Flutter caregiver monitoring application
└── bin/                # Packaged ffmpeg/ffprobe binaries (local, no system install needed)

## How to Run

### 1. Install Python dependencies
```bash
pip install tensorflow==2.16.2 keras==3.10.0 librosa==0.11.0 firebase-admin==7.1.0
```

### 2. Configure Firebase
A new Firebase project and service-account key must be configured locally before
the full edge-to-cloud pipeline can run. Place the service-account JSON at the path
expected by `src/firebase_publisher.py` and update `src/realtime_detect.py` accordingly.
Firebase credentials are not included in this submission for security reasons.

### 3. Preprocess audio (optional — processed files already included)
```bash
python scripts/process_audio.py
```

### 4. Train TinyCNN V1 (optional — trained model already included)
```bash
python src/train_tinycnn.py
```

### 5. Run real-time detection
```bash
python src/realtime_detect.py
```

### 6. Run Flutter app
```bash
cd aurality_monitor
flutter pub get
flutter run -d macos
```

If another target is required:
```bash
flutter devices
flutter run -d <device-id>
```

## Key Files

- `models/tinycnn_best.keras` — Production model checkpoint (V1, 23,827 parameters)
- `models/thresholds.json` — Validation-frozen thresholds (τ = 0.35 per class)
- `docs/dataset_log.xlsx` — Full clip-level provenance catalogue
- `splits/test.csv` — Held-out test set used for evaluation in the final report
- `results/test_classification_report.txt` — Full per-class evaluation results
- `results/val_prob_audit.csv` — Validation probability audit confirming low-confidence regime

## Known Limitations

- The final evaluated prototype runs on a MacBook Air M2 as an edge-development proxy,
  not on Raspberry Pi hardware.
- TensorFlow Lite export exists as an experimental utility (`src/export_tflite.py`) but
  was not used in the final evaluated system.
- Firebase credentials are excluded for security reasons. Cloud functionality requires
  local Firebase configuration before the edge-to-cloud pipeline will operate.
- End-to-end latency depends on local network conditions and Firebase availability.
  All reported figures (under 5 seconds) were measured over local Wi-Fi.

## Notes

- All absolute paths in scripts are set for macOS. Adjust if running on Windows or Linux.
- Random seed 42 is fixed across all scripts for reproducibility.
- V1 and V2 model variants are both included in `models/` to support the architectural
  comparison reported in Section 6.4 of the final report.