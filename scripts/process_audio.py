import os
import sys

# Add local bin to path for ffmpeg
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bin_dir = os.path.join(project_root, "bin")
os.environ["PATH"] += os.pathsep + bin_dir

from pydub import AudioSegment

# --- ML STANDARDIZATION CONFIGURATION ---
TARGET_DBFS = -20.0              # Normalization target
TARGET_SAMPLE_RATE = 22050       # Standardize sample rate for ML (22.05 kHz)
TARGET_CHANNELS = 1              # Convert to Mono

# The three folders we need to process
CATEGORIES = ["shouting", "glass_break", "alarm"]

def match_target_amplitude(sound, target_dBFS):
    change_in_dBFS = target_dBFS - sound.dBFS
    return sound.apply_gain(change_in_dBFS)

def process_all_clips():
    print("Starting Aurality Data Preprocessing (Standardization Only)...\n")

    for category in CATEGORIES:
        input_folder = f"../data/raw/{category}"
        output_folder = f"../data/processed/{category}"

        # Create output folder if it doesn't exist
        if not os.path.exists(output_folder):
            os.makedirs(output_folder)

        # Check if input folder exists
        if not os.path.exists(input_folder):
            print(f"⚠️ Skipping '{category}': Folder '{input_folder}' not found.")
            continue

        print(f"--- Processing Category: {category} ---")
        processed_count = 0

        # Loop through all files in the raw folder
        for filename in os.listdir(input_folder):
            if filename.lower().endswith(".wav"):
                path = os.path.join(input_folder, filename)
                
                try:
                    # Load the audio
                    audio = AudioSegment.from_wav(path)
                    
                    # 1. Convert to Mono
                    audio = audio.set_channels(TARGET_CHANNELS)
                    
                    # 2. Standardize Sample Rate
                    audio = audio.set_frame_rate(TARGET_SAMPLE_RATE)
                    
                    # 3. Normalize volume
                    audio = match_target_amplitude(audio, TARGET_DBFS)

                    # 4. Export with the EXACT SAME FILENAME
                    output_path = os.path.join(output_folder, filename)
                    audio.export(output_path, format="wav")
                    
                    processed_count += 1
                    print(f"  -> Processed: {filename}")
                    
                except Exception as e:
                    print(f"  ❌ Error processing {filename}: {e}")

        print(f"✅ Finished '{category}': {processed_count} clips standardized.\n")

if __name__ == "__main__":
    process_all_clips()