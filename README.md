Non-Invasive Anemia Screening & Longitudinal Health Monitoring
This project is a clinical-grade Flutter application designed for non-invasive anemia screening using computer vision and IoT sensor data. It utilizes image capture of specific physiological sites (Conjunctiva, Nails, Palm) and sensor-based vitals to provide a comprehensive health assessment.

🌟 Clinical Screening Methods
Ocular Conjunctiva Analysis: Captures and analyzes the pallor of the lower eyelid conjunctiva.

Nail Bed & Palm Pallor Detection: Visual assessment of peripheral perfusion and hemoglobin indicators.

IoT Vital Monitoring: Real-time SpO2 and Heart Rate data acquisition via ESP32/Arduino and the MAX30102 sensor.

Patient Questionnaire: Structured data collection to supplement physiological markers.

🛠️ Technical Architecture
Frontend: Flutter (Mobile & Web)

State Management: Provider / ScanProvider for real-time data flow.

Backend: Firebase (Authentication & Cloud Firestore).

Hardware Interface: Serial communication support for ESP32/Arduino integration.

Deployment: Optimized for Vercel.

📂 Key Project Modules
lib/screens/: Contains the core diagnostic UI, including specialized camera capture screens for different body parts.

lib/services/: Manages auth_service.dart for secure patient data and scan_provider.dart for processing sensor/image inputs.

assets/: Storage for custom fonts, icons, and medical reference images.

🚀 Getting Started
Prerequisites
Flutter SDK (Latest Stable)

Node.js (for Vercel deployment)

ESP32/Arduino hardware for sensor-based features.

Installation
Clone & Install:

Bash
git clone https://github.com/your-username/anemia_app.git
cd anemia_app
flutter pub get
Run Locally:

Bash
flutter run
🌐 Web Deployment (Vercel)
To push updates to your live production environment:

Generate Release Build:

Bash
flutter build web --release
Deploy via CLI:

Bash
cd build/web
vercel --prod --force
📄 Research & Authorship
Developed as part of a biomedical engineering research initiative focusing on affordable, non-invasive diagnostic tools.

Lead Developer: Gayathri S. H.

Supervision: Department of Biomedical Engineering, SRM Institute of Science and Technology.
