# AuraSkin AI

AuraSkin AI is a premium skin analysis companion and facial aesthetics guide designed to help users track and improve their skin health and facial structure.

---

## 🌟 Key Features

### 1. Dual-Layer Interactive Face Analysis
- **Skin Care Layer**: Visually maps and highlights acne, dark circles, wrinkles, oiliness, and redness hotspots on user-uploaded or captured photos.
- **Facial Structure Layer**: Draws a glowing golden wireframe grid showing anatomical vertical thirds (forehead, midface, and lower third ratios), sagittal midline symmetry, eye alignment, and jawline slope angles.
- **Interactive Highlighting**: Tapping on visual hotspots on the face highlights their respective analysis card in the details list.

### 2. Qoves-Inspired Aesthetics Metrics
- **Bilateral Symmetry Score**: Runs an RGB luminance and color deviation scan between left and right facial zones to output a bilateral symmetry percentage.
- **Vertical Thirds Proportions**: Checks height ratios against the classic 1:1:1 proportion.
- **Mandibular Slope**: Estimates the gonial angle of the jawline in degrees.

### 3. Face Sculpting & Toning Routines
- Actionable guidelines and checkable daily routines for:
  - **Mewing** (correct tongue posture)
  - **Gua Sha drainage sweeps**
  - **Zygomatic Cheek Lifts**
  - **Posture adjustments**
- A habit-tracker dashboard to log progress and complete routines.

### 4. Scan History & Compare Slider
- Visual swipe comparison slider to evaluate changes between "Before" and "After" scans side-by-side.
- Historical progress chart plotting total skin scores over time.

---

## 💻 Tech Stack & Platforms
- **Framework**: Flutter
- **Database / Auth**: Firebase Auth & Cloud Firestore (supported on mobile), and an offline **Local Demo Mode** fallback (shared_preferences & memory cache) for desktop environments.
- **Desktop Ready**: Fully configured and compiled for **Windows** with optimized CMake install prefixes and C++ stubs.

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (Channel stable)
- Visual Studio (for Windows compilation) / Android SDK (for mobile packaging)

### Run the App
```bash
flutter pub get
flutter run
```
