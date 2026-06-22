# NutriScan Offline — ML-Powered Food Ingredient Scanner

> Real-time nutrition label analysis using Computer Vision and NLP, built to work completely offline.

![Python](https://img.shields.io/badge/Python-3.10-blue?style=flat-square&logo=python)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)
![YOLOv8](https://img.shields.io/badge/YOLOv8-Object%20Detection-orange?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## Download

| Platform | Link |
|----------|------|
| **Android (ARM64)** | [`app-arm64-v8a-release.apk`](./build/app/outputs/flutter-apk/app-arm64-v8a-release.apk) |

> **Requirements:** Android 8.0+ (API 26), ARM64 processor, ~200MB free storage.  
> Enable **"Install from unknown sources"** in your phone settings before installing.

---

## The Problem

Consumers face friction when checking nutritional information while shopping — apps require internet, manual label reading is slow and error-prone, and understanding health implications takes background knowledge most people don't have. NutriScan solves this by instantly scanning, extracting, and analyzing any food label in under 2 seconds, entirely on-device.

---

## What We Built

A production-ready food intelligence platform with three integrated layers:

- **ML Pipeline**: YOLOv8 (ingredient detection) → PaddleOCR (text extraction) → scikit-learn (Nutri-Score classification)
- **Mobile App**: Flutter cross-platform app (Android) with on-device ONNX inference
- **Backend**: FastAPI inference server with RAG pipeline for health explanations

### Key Metrics

| Metric | Result |
|--------|--------|
| Classification Accuracy | **80.5%** on 134K food products |
| OCR Accuracy | **92%** on nutrition labels |
| Inference Speed | **< 2 seconds** end-to-end on mid-range devices |
| Model Footprint | **~180MB** (quantized + ONNX) |
| Internet Required | **None** — fully offline |

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│          Flutter Mobile App (Android)            │
│  Camera → Preprocessing → On-Device Inference   │
│  ONNX Runtime · SQLite Cache · Material 3 UI    │
└─────────────────────┬────────────────────────────┘
                      │  (optional cloud fallback)
         ┌────────────▼────────────┐
         │    FastAPI Backend      │
         │  RAG · Health Context  │
         └────────────┬────────────┘
                      │
         ┌────────────▼────────────┐
         │    ML Inference Stack   │
         ├─────────────────────────┤
         │  YOLOv8   → Detection   │
         │  PaddleOCR → OCR        │
         │  scikit-learn → Scoring │
         └─────────────────────────┘
```

### Data Flow

1. **Capture** — Camera captures food label or packaging
2. **Preprocess** — Resize, normalize, denoise for ML input
3. **Detect** — YOLOv8 localizes ingredient and nutrition regions (bounding boxes)
4. **Extract** — PaddleOCR pulls text from detected regions
5. **Score** — LightGBM classifier assigns Nutri-Score (A–E) and flags health risks
6. **Explain** — RAG pipeline retrieves ingredient context and health implications
7. **Cache** — Results stored locally in SQLite; nothing leaves the device

---

## Technical Highlights

### 1. On-Device ML — No Cloud Dependency

All models quantized and bundled inside the app for offline-first inference:

```python
# YOLOv8 quantized inference — runs on device CPU
from ultralytics import YOLO

model = YOLO('yolov8n-int8.pt')  # Int8 quantized, ~6MB
results = model.predict(image, conf=0.6, device='cpu')
boxes = results[0].boxes.xyxy.tolist()
```

Int8 quantization reduced model size by 50% with only a 2% accuracy drop.

---

### 2. LightGBM Classifier — Nutri-Score Prediction

Trained on 134K food products from Open Food Facts dataset:

```python
import lightgbm as lgb

model = lgb.LGBMClassifier(n_estimators=500, max_depth=8)
model.fit(X_train, y_train)
# Accuracy: 80.5% on held-out test set
```

Features: ingredient count, sugar/fat/protein ratios, additive flags, serving size normalization.

---

### 3. PaddleOCR — Real-Time Text Extraction

Extracts ingredient lists and nutritional facts from label images:

```python
from paddleocr import PaddleOCR

ocr = PaddleOCR(use_angle_cls=True, lang='en', use_gpu=False)
result = ocr.ocr(image_path)
# Returns: [(bounding_box, (text, confidence)), ...]
ingredients = parse_ingredient_block(result)
```

Handles angled labels, low-contrast text, and small print.

---

### 4. RAG Pipeline — Health Intelligence

Ingredient list feeds a Retrieval-Augmented Generation pipeline for plain-English explanations:

```python
# Vector search over ingredient knowledge base
query_embedding = embed(ingredients)
top_k = faiss_index.search(query_embedding, k=5)
explanation = generate_health_summary(ingredients, top_k)
```

Explains additives, allergens, and health risk factors in plain language.

---

### 5. Flutter — Cross-Platform Delivery

Single Dart codebase with on-device ONNX inference:

```dart
// Run model inference inside Flutter
final interpreter = Interpreter.fromAsset('yolov8.onnx');
final input = preprocessImage(cameraFrame);
final output = List.filled(outputShape, 0.0).reshape(outputDims);
interpreter.run(input, output);
setState(() => detections = parseOutput(output));
```

Features: `camera` plugin, `onnxruntime` Flutter package, SQLite history, Material 3 design.

---

## Repository Structure

```
nutriscan-offline/
├── lib/                          # Flutter app source
│   ├── screens/                  # Camera, results, history screens
│   ├── services/                 # Inference, OCR, storage services
│   └── models/                   # Dart data models
├── backend/                      # FastAPI + RAG pipeline
│   ├── app.py                    # API server
│   ├── ml_pipeline.py            # Inference pipeline
│   ├── rag_pipeline.py           # Health explanation retrieval
│   └── requirements.txt
├── ml/                           # Training scripts
│   ├── train_classifier.py       # LightGBM training
│   ├── yolov8_finetune.py        # YOLOv8 fine-tuning
│   └── evaluate.py               # Accuracy & metrics
├── models/                       # Quantized model weights
│   ├── yolov8n-int8.pt
│   ├── paddleocr/
│   └── nutriscore_lgbm.pkl
├── build/
│   └── app/outputs/flutter-apk/
│       └── app-arm64-v8a-release.apk   ← installable APK
├── tests/
│   ├── test_ocr.py
│   ├── test_detection.py
│   └── test_classification.py
└── README.md
```

---

## Running Locally

### Flutter App

```bash
# Install Flutter dependencies
flutter pub get

# Run on connected Android device
flutter run -d <device-id>

# Build release APK
flutter build apk --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Backend (Optional — for cloud fallback)

```bash
pip install -r backend/requirements.txt
uvicorn backend.app:app --reload --port 8000
```

### ML Training

```bash
pip install -r ml/requirements.txt

# Train Nutri-Score classifier
python ml/train_classifier.py --data data/open_food_facts.csv

# Fine-tune YOLOv8 on label detection
python ml/yolov8_finetune.py --epochs 50 --imgsz 640

# Evaluate pipeline end-to-end
python ml/evaluate.py --test-set data/test_images/
```

---

## Engineering Decisions

| Decision | Chosen | Alternative | Reason |
|----------|--------|-------------|--------|
| Object Detection | YOLOv8n | Faster R-CNN | 3x faster, smaller footprint |
| Classifier | LightGBM | XGBoost | 30% faster training, same accuracy |
| Quantization | Int8 | FP16 | Smaller file, runs on CPU |
| Mobile Framework | Flutter | React Native | Better ONNX runtime support |
| OCR Engine | PaddleOCR | Tesseract | Handles angled/low-contrast text |

---

## What This Demonstrates

- **End-to-end ownership** — data collection, model training, quantization, mobile packaging, and APK deployment
- **AI-native product thinking** — every feature decision driven by model tradeoffs (speed vs. accuracy vs. size)
- **Production constraints** — solved real problems: latency, privacy, model size, offline reliability
- **Ship mentality** — working APK, tested on real hardware, real data, real users

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x, Dart |
| ML Inference | YOLOv8, PaddleOCR, LightGBM, ONNX Runtime |
| Backend | FastAPI, Python 3.10 |
| RAG | FAISS, sentence-transformers |
| Data | SQLite (local), pandas, Open Food Facts (134K products) |
| DevOps | GitHub, GitHub Actions |

---

*Built from scratch. Trained on real data. Shipped as a working app.*