# 💡 ShellyPlugS Energy Monitor

A full-stack application built with **Node.js**, **Flutter**, and **PostgreSQL** that monitors energy usage using data from **ShellyPlugS** smart plugs. The backend reads real-time data from the ShellyPlugS API and stores it in a PostgreSQL database. A Flutter-based mobile app then visualizes energy consumption trends and statistics.

---

## 🛠️ Tech Stack

| Layer      | Technology     |
|------------|----------------|
| Backend    | Node.js        |
| Database   | PostgreSQL     |
| Frontend   | Flutter (Mobile) |
| Hardware   | ShellyPlugS    |

---

## 🔄 How It Works

1. **Data Collection**
   - Node.js backend polls the ShellyPlugS API.
   - Extracts real-time power consumption data.

2. **Database Storage**
   - Parsed data is stored in a PostgreSQL database.
   - Includes timestamped energy usage logs per device.

3. **Mobile App Display**
   - Flutter app fetches data from the backend.
   - Displays energy usage trends, device stats, and estimated costs.

---


