import os
import uuid
import datetime
import firebase_admin
from firebase_admin import credentials, firestore, storage
from typing import Optional, Dict, Any

_DB = None
_BUCKET = None

# 1. Fixed the argument to match what you're actually using
def init_firebase(service_key_path: str = "credentials/serviceAccountKey.json"):
    global _DB, _BUCKET
    if _DB is not None:
        return _DB, _BUCKET

    if not os.path.exists(service_key_path):
        raise FileNotFoundError(f"Firebase key not found at: {service_key_path}")

    if not firebase_admin._apps:
        # 2. Fixed indentation here
        cred = credentials.Certificate(service_key_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'aurality-iup.firebasestorage.app' 
        })

    _DB = firestore.client()
    _BUCKET = storage.bucket()
    return _DB, _BUCKET

def publish_alert(
    event_type: str,
    confidence: float,
    local_audio_path: str,
    all_probs: Dict[str, float],
    margin: float,
    device_id: str = "macbook_edge_01",
    collection: str = "alerts",
) -> str:
    db, bucket = init_firebase()

    # 1. Unique traceable filename
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    unique_id = uuid.uuid4().hex[:6]
    filename = f"{event_type.lower()}_{ts}_{unique_id}.wav"
    storage_path = f"recordings/{filename}"

    # 2. Upload Audio (STAYS PRIVATE)
    blob = bucket.blob(storage_path)
    blob.upload_from_filename(local_audio_path, content_type="audio/wav")
    
    # 3. Payload
    payload = {
        "eventType": event_type,
        "confidence": float(confidence),
        "margin": float(margin),
        "allProbabilities": all_probs,
        "deviceId": device_id,
        "status": "new",
        "storagePath": storage_path,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "metadata": {
            "modelVersion": "tinycnn_v1_frozen",
            "thresholdProfile": "v2_temporal_refined",
            "privacyAccess": "restricted_authenticated"
        }
    }

    doc_ref = db.collection(collection).document()
    doc_ref.set(payload)
    return doc_ref.id
    